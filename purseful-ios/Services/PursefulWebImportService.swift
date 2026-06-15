import Foundation
import SwiftData

enum PursefulWebImportService {
    struct WebBackup: Decodable {
        let accounts: [WebAccount]?
        let categories: [WebCategory]?
        let transactions: [WebTransaction]?
        let settings: WebSettings?
    }

    struct WebAccount: Decodable, Identifiable {
        let id: String
        let name: String
        let type: String
        let currency: String
        let balance: Double?
        let color: String?
        let icon: String?
    }

    struct WebCategory: Decodable, Identifiable {
        let id: String
        let name: String
        let type: String
        let color: String?
        let icon: String?
    }

    struct WebTransaction: Decodable, Identifiable {
        let id: String
        let accountId: String
        let categoryId: String?
        let type: String
        let amount: Double
        let currency: String?
        let date: String
        let note: String?
        let toAccountId: String?
        let createdAt: String?
        let updatedAt: String?
    }

    struct WebSettings: Decodable {
        let mainCurrency: String?
    }

    enum MappingTarget: Hashable {
        case createNew
        case existing(UUID)
    }

    struct ImportMappings {
        var accounts: [String: MappingTarget] = [:]
        var categories: [String: MappingTarget] = [:]
    }

    struct ImportResult {
        let accounts: Int
        let categories: Int
        let transactions: Int
        let skippedDuplicates: Int
        let skippedInvalid: Int
    }

    struct ParsedTransactionDates {
        let transactionDate: Date
        let createdAt: Date
    }

    private struct ParsedWebTransactionDate {
        let transactionDate: Date
        let createdAt: Date
    }

    static func parseBackup(data: Data) throws -> WebBackup {
        try JSONDecoder().decode(WebBackup.self, from: data)
    }

    static func suggestedMappings(
        backup: WebBackup,
        existingAccounts: [Account],
        existingCategories: [Category]
    ) -> ImportMappings {
        var mappings = ImportMappings()

        for webAccount in backup.accounts ?? [] {
            if let match = existingAccounts.first(where: {
                $0.name.localizedCaseInsensitiveCompare(webAccount.name) == .orderedSame
            }) {
                mappings.accounts[webAccount.id] = .existing(match.id)
            } else {
                mappings.accounts[webAccount.id] = .createNew
            }
        }

        for webCategory in backup.categories ?? [] {
            let categoryType: CategoryType = webCategory.type == "income" ? .income : .expense
            if let match = existingCategories.first(where: {
                $0.type == categoryType
                    && $0.name.localizedCaseInsensitiveCompare(webCategory.name) == .orderedSame
            }) {
                mappings.categories[webCategory.id] = .existing(match.id)
            } else {
                mappings.categories[webCategory.id] = .createNew
            }
        }

        return mappings
    }

    @MainActor
    static func importBackup(
        backup: WebBackup,
        context: ModelContext,
        merge: Bool,
        mappings: ImportMappings
    ) throws -> ImportResult {
        if !merge {
            try deleteAllEntities(context: context)
        }

        let existingAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let existingCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        var accountMap: [String: Account] = [:]
        var categoryMap: [String: Category] = [:]
        var createdAccounts: [Account] = []

        for webAccount in backup.accounts ?? [] {
            guard let target = mappings.accounts[webAccount.id] else { continue }

            switch target {
            case .existing(let id):
                if let account = existingAccounts.first(where: { $0.id == id })
                    ?? createdAccounts.first(where: { $0.id == id }) {
                    accountMap[webAccount.id] = account
                }
            case .createNew:
                let account = Account(
                    name: webAccount.name,
                    type: mapAccountType(webAccount.type),
                    currency: webAccount.currency,
                    initialBalance: 0,
                    colorHex: webAccount.color ?? "#007AFF",
                    icon: mapIcon(webAccount.icon)
                )
                account.sortOrder = AccountPreferences.nextSortOrder(
                    accounts: existingAccounts + createdAccounts
                )
                context.insert(account)
                createdAccounts.append(account)
                accountMap[webAccount.id] = account
            }
        }

        var createdCategories: [Category] = []

        for webCategory in backup.categories ?? [] {
            guard let target = mappings.categories[webCategory.id] else { continue }

            switch target {
            case .existing(let id):
                if let category = existingCategories.first(where: { $0.id == id })
                    ?? createdCategories.first(where: { $0.id == id }) {
                    categoryMap[webCategory.id] = category
                }
            case .createNew:
                let category = Category(
                    name: webCategory.name,
                    icon: mapIcon(webCategory.icon),
                    colorHex: webCategory.color ?? "#8E8E93",
                    type: webCategory.type == "income" ? .income : .expense,
                    isSystem: false
                )
                context.insert(category)
                createdCategories.append(category)
                categoryMap[webCategory.id] = category
            }
        }

        let sortedTransactions = (backup.transactions ?? []).sorted { lhs, rhs in
            let left = parseWebTransactionDatesOptional(date: lhs.date, createdAt: lhs.createdAt)
            let right = parseWebTransactionDatesOptional(date: rhs.date, createdAt: rhs.createdAt)

            switch (left, right) {
            case let (l?, r?):
                if l.transactionDate != r.transactionDate {
                    return l.transactionDate < r.transactionDate
                }
                if l.createdAt != r.createdAt {
                    return l.createdAt < r.createdAt
                }
                return lhs.id < rhs.id
            case (nil, nil):
                return lhs.id < rhs.id
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }

        var importedTransactions = 0
        var skippedDuplicates = 0
        var skippedInvalid = 0

        let webCategoriesByID = Dictionary(uniqueKeysWithValues: (backup.categories ?? []).map { ($0.id, $0) })
        let existingImportIDs = merge ? existingImportSourceIDs(context: context) : []

        for webTx in sortedTransactions {
            guard let account = accountMap[webTx.accountId] else { continue }

            if merge, existingImportIDs.contains(webTx.id) {
                skippedDuplicates += 1
                continue
            }

            guard let parsedDates = parseWebTransactionDates(date: webTx.date, createdAt: webTx.createdAt) else {
                skippedInvalid += 1
                continue
            }

            let txType: TransactionType
            switch webTx.type {
            case "income": txType = .income
            case "transfer": txType = .transfer
            default: txType = .expense
            }

            let category: Category?
            if let categoryId = webTx.categoryId, !categoryId.isEmpty {
                category = categoryMap[categoryId]
            } else {
                category = nil
            }

            let resolvedCategory = CategoryService.resolvedCategory(category, for: txType, context: context)
            let toAccount = webTx.toAccountId.flatMap { accountMap[$0] }
            let title = transactionTitle(
                note: webTx.note,
                type: txType,
                mappedCategory: category,
                webCategoryID: webTx.categoryId,
                webCategoriesByID: webCategoriesByID
            )

            let transaction = Transaction(
                title: title,
                amount: Decimal(webTx.amount),
                type: txType,
                date: parsedDates.transactionDate,
                note: webTx.note ?? "",
                account: account,
                toAccount: toAccount,
                category: resolvedCategory,
                transactionCurrency: webTx.currency,
                exchangeRate: nil,
                importSourceID: webTx.id
            )
            transaction.createdAt = parsedDates.createdAt
            context.insert(transaction)
            importedTransactions += 1
        }

        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        reconcileAccountBalances(
            accountMap: accountMap,
            webAccounts: backup.accounts ?? [],
            transactions: allTransactions
        )

        if let mainCurrency = backup.settings?.mainCurrency {
            AppSettings.shared.baseCurrency = mainCurrency
        }

        try context.save()
        return ImportResult(
            accounts: accountMap.count,
            categories: categoryMap.count,
            transactions: importedTransactions,
            skippedDuplicates: skippedDuplicates,
            skippedInvalid: skippedInvalid
        )
    }

    @MainActor
    static func importBackup(
        data: Data,
        context: ModelContext,
        merge: Bool = true,
        mappings: ImportMappings? = nil
    ) throws -> ImportResult {
        let backup = try parseBackup(data: data)
        let resolvedMappings = mappings ?? suggestedMappings(
            backup: backup,
            existingAccounts: (try? context.fetch(FetchDescriptor<Account>())) ?? [],
            existingCategories: (try? context.fetch(FetchDescriptor<Category>())) ?? []
        )
        return try importBackup(
            backup: backup,
            context: context,
            merge: merge,
            mappings: resolvedMappings
        )
    }

    static func parseWebTransactionDates(date: String, createdAt: String?) -> ParsedTransactionDates? {
        guard let parsed = parseWebTransactionDatesOptional(date: date, createdAt: createdAt) else { return nil }
        return ParsedTransactionDates(
            transactionDate: parsed.transactionDate,
            createdAt: parsed.createdAt
        )
    }

    private static func parseWebTransactionDatesOptional(date: String, createdAt: String?) -> ParsedWebTransactionDate? {
        let calendar = Calendar.current
        let transactionDate: Date

        if let localDay = localDayFormatter.date(from: date) {
            transactionDate = calendar.startOfDay(for: localDay)
        } else if let isoDate = parseISO8601(date) {
            transactionDate = calendar.startOfDay(for: isoDate)
        } else {
            return nil
        }

        let created = createdAt.flatMap(parseISO8601) ?? transactionDate
        return ParsedWebTransactionDate(transactionDate: transactionDate, createdAt: created)
    }

    private static func existingImportSourceIDs(context: ModelContext) -> Set<String> {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        return Set(transactions.compactMap(\.importSourceID))
    }

    private static func reconcileAccountBalances(
        accountMap: [String: Account],
        webAccounts: [WebAccount],
        transactions: [Transaction]
    ) {
        var targetBalanceByAccountID: [UUID: Decimal] = [:]
        var accountByID: [UUID: Account] = [:]

        for webAccount in webAccounts {
            guard let account = accountMap[webAccount.id] else { continue }
            targetBalanceByAccountID[account.id, default: 0] += Decimal(webAccount.balance ?? 0)
            accountByID[account.id] = account
        }

        for (accountID, targetBalance) in targetBalanceByAccountID {
            guard let account = accountByID[accountID] else { continue }
            let netEffect = BalanceCalculator.transactionNetEffect(for: account, transactions: transactions)
            account.initialBalance = targetBalance - netEffect
        }
    }

    private static func transactionTitle(
        note: String?,
        type: TransactionType,
        mappedCategory: Category?,
        webCategoryID: String?,
        webCategoriesByID: [String: WebCategory]
    ) -> String {
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note
        }

        if let mappedCategory {
            return mappedCategory.name
        }

        if let webCategoryID,
           !webCategoryID.isEmpty,
           let webCategory = webCategoriesByID[webCategoryID] {
            return webCategory.name
        }

        return type.displayName
    }

    @MainActor
    static func clearAllData(context: ModelContext) throws {
        try deleteAllEntities(context: context)
        UserDefaults.standard.set(false, forKey: AppConstants.hasSeededCategoriesKey)
        SeedDataService.seedIfNeeded(context: context, force: true)
    }

    @MainActor
    static func replaceAllData(context: ModelContext) throws {
        try deleteAllEntities(context: context)
    }

    @MainActor
    private static func deleteAllEntities(context: ModelContext) throws {
        try deleteAll(Transaction.self, context: context)
        try deleteAll(PlannedPayment.self, context: context)
        try deleteAll(Debt.self, context: context)
        try deleteAll(Goal.self, context: context)
        try deleteAll(Budget.self, context: context)
        try deleteAll(RecurringRule.self, context: context)
        try deleteAll(ShoppingListItem.self, context: context)
        try deleteAll(BankConnection.self, context: context)
        try deleteAll(Account.self, context: context)
        try deleteAll(Category.self, context: context)
        try context.save()
    }

    @MainActor
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        items.forEach { context.delete($0) }
    }

    private static let localDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private nonisolated static func parseISO8601(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFraction.date(from: value) ?? plain.date(from: value)
    }

    private static func mapAccountType(_ type: String) -> AccountType {
        switch type.lowercased() {
        case "cash": .cash
        case "card", "debit": .debitCard
        case "credit": .creditCard
        case "savings": .savings
        case "bank": .savings
        case "loan": .loan
        default: .cash
        }
    }

    private static func mapIcon(_ webIcon: String?) -> String {
        guard let webIcon else { return "banknote" }
        switch webIcon.lowercased() {
        case "wallet": return "wallet.pass"
        case "utensilscrossed": return "fork.knife"
        case "briefcase": return "briefcase"
        case "laptop": return "laptopcomputer"
        case "trendingup": return "chart.line.uptrend.xyaxis"
        case "dollarsign": return "dollarsign.circle"
        case "shoppingbag": return "bag"
        case "car": return "car"
        case "home": return "house"
        case "film": return "film"
        case "heart": return "heart"
        case "graduationcap": return "graduationcap"
        case "morehorizontal": return "ellipsis.circle"
        default: return "tag"
        }
    }
}
