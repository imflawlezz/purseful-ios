import SwiftData
import SwiftUI

struct TransactionFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]

    var transaction: Transaction?
    var showsCancelButton = false

    @State private var title = ""
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var date = Date()
    @State private var note = ""
    @State private var selectedAccount: Account?
    @State private var selectedToAccount: Account?
    @State private var selectedCategory: Category?
    @State private var isSplitEnabled = false
    @State private var additionalSplits: [SplitLine] = []
    @State private var showScanner = false
    @State private var pendingAttachmentData: Data?
    @State private var receiptScanMessage: String?

    struct SplitLine: Identifiable {
        let id = UUID()
        var category: Category?
        var amountText: String
    }

    private var currencyCode: String {
        selectedAccount?.currency ?? AppSettings.shared.baseCurrency
    }

    private var totalAmount: Decimal? {
        CurrencyFormatter.parse(amountText)
    }

    private var additionalSplitTotal: Decimal {
        additionalSplits.compactMap { CurrencyFormatter.parse($0.amountText) }.reduce(0, +)
    }

    private var primarySplitAmount: Decimal {
        guard let total = totalAmount else { return 0 }
        return max(0, total - additionalSplitTotal)
    }

    var body: some View {
        Form {
                Section {
                    Picker("field.type", selection: $type) {
                        ForEach(TransactionType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    TextField("Title", text: $title)
                    LabeledAmountField(label: String(localized: "Amount"), amount: $amountText, currencyCode: currencyCode)
                    .onChange(of: amountText) { _, _ in
                        clampAllSplitAmounts()
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note", text: $note, axis: .vertical)
                    Picker("Account", selection: $selectedAccount) {
                        Text("Select").tag(Optional<Account>.none)
                        ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                            Text(account.selectionLabel).tag(Optional(account))
                        }
                    }
                    if type == .transfer {
                        Picker("To Account", selection: $selectedToAccount) {
                            Text("Select").tag(Optional<Account>.none)
                            ForEach(AccountPreferences.visibleAccounts(accounts).filter { $0.id != selectedAccount?.id }) { account in
                                Text(account.selectionLabel).tag(Optional(account))
                            }
                        }
                    }
                    if type != .transfer {
                        if isDebtLinkedTransaction {
                            LabeledContent("Category") {
                                CategoryNameLabel(category: selectedCategory)
                            }
                        } else {
                            Picker("Category", selection: $selectedCategory) {
                                Text("Select").tag(Optional<Category>.none)
                                ForEach(filteredCategories) { category in
                                    CategoryNameLabel.picker(category: category).tag(Optional(category))
                                }
                            }
                        }
                    }
                } header: {
                    AccentListSectionHeader(title: "Details")
                }
                .accentListRows()

                if type != .transfer, !isDebtLinkedTransaction {
                    Section {
                        Toggle("Split transaction", isOn: $isSplitEnabled)
                            .onChange(of: isSplitEnabled) { _, enabled in
                                if !enabled { additionalSplits.removeAll() }
                            }

                        if isSplitEnabled {
                            primarySplitRow

                            ForEach($additionalSplits) { $split in
                                additionalSplitRow($split)
                            }

                            FormActionButton(
                                title: String(localized: "Add split"),
                                systemImage: "plus",
                                disabled: !canAddSplitLine
                            ) {
                                additionalSplits.append(SplitLine(category: nil, amountText: ""))
                            }
                        }
                    }
                    .accentListRows()
                }
        }
        .dismissKeyboardOnTap()
        .navigationTitle(transaction == nil ? "New Transaction" : "Edit Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .accentTintedBackground()
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIcon.cancel { dismiss() }
                }
            }
            if transaction != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarIcon.delete { deleteTransaction() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showScanner = true } label: {
                    Image(systemName: "doc.text.viewfinder")
                }
                .accessibilityLabel(String(localized: "Scan receipt"))
            }
            ToolbarItem(placement: .confirmationAction) {
                ToolbarIcon.save({ save() }, disabled: !canSave)
            }
        }
        .onAppear {
            loadTransaction()
            if transaction == nil, selectedAccount == nil {
                selectedAccount = AccountPreferences.preferredAccount(from: accounts)
            }
        }
        .onChange(of: selectedCategory) { _, newCategory in
            guard let newCategory else { return }
            for index in additionalSplits.indices where additionalSplits[index].category?.id == newCategory.id {
                additionalSplits[index].category = nil
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView { image in
                Task { await processReceipt(image) }
            }
        }
        .alert("Receipt scan", isPresented: Binding(
            get: { receiptScanMessage != nil },
            set: { if !$0 { receiptScanMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(receiptScanMessage ?? "")
        }
    }

    private var filteredCategories: [Category] {
        let categoryType: CategoryType = type == .income ? .income : .expense
        return Category.userSelectable(categories, type: categoryType)
    }

    private var isDebtLinkedTransaction: Bool {
        guard let transaction else { return false }
        return DebtService.isDebtLinkedTransaction(transaction)
    }

    private var primarySplitRow: some View {
        HStack {
            CategoryNameLabel(category: selectedCategory)
            Spacer(minLength: 12)
            splitAmountDisplay(primarySplitAmount)
        }
    }

    private func usedCategoryIDs(excludingSplitID: UUID? = nil) -> Set<UUID> {
        var ids = Set<UUID>()
        if let selectedCategory {
            ids.insert(selectedCategory.id)
        }
        for split in additionalSplits where split.id != excludingSplitID {
            if let category = split.category {
                ids.insert(category.id)
            }
        }
        return ids
    }

    private func categoriesAvailable(for selection: Binding<Category?>, splitID: UUID) -> [Category] {
        let used = usedCategoryIDs(excludingSplitID: splitID)
        return filteredCategories.filter { category in
            category.id == selection.wrappedValue?.id || !used.contains(category.id)
        }
    }

    private var canAddSplitLine: Bool {
        filteredCategories.contains { !usedCategoryIDs().contains($0.id) }
    }

    private var splitCategoriesAreUnique: Bool {
        var seen = Set<UUID>()
        if let selectedCategory {
            if seen.contains(selectedCategory.id) { return false }
            seen.insert(selectedCategory.id)
        }
        for split in additionalSplits {
            guard let category = split.category else { return false }
            if seen.contains(category.id) { return false }
            seen.insert(category.id)
        }
        return true
    }

    private func additionalSplitRow(_ split: Binding<SplitLine>) -> some View {
        HStack {
            splitCategoryPicker(selection: split.category, splitID: split.wrappedValue.id)
            Spacer(minLength: 12)
            splitAmountField(split)
        }
    }

    private func splitCategoryPicker(selection: Binding<Category?>, splitID: UUID) -> some View {
        Menu {
            Picker("Category", selection: selection) {
                Text("Select").tag(Optional<Category>.none)
                ForEach(categoriesAvailable(for: selection, splitID: splitID)) { category in
                    CategoryNameLabel.picker(category: category).tag(Optional(category))
                }
            }
        } label: {
            HStack(spacing: 6) {
                CategoryNameLabel.picker(
                    category: selection.wrappedValue,
                    iconSize: 20
                )
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func splitAmountField(_ split: Binding<SplitLine>) -> some View {
        CurrencyAmountInput(amount: split.amountText, currencyCode: currencyCode)
            .fixedSize(horizontal: true, vertical: false)
            .onChange(of: split.wrappedValue.amountText) { _, newValue in
                enforceSplitLimit(for: split.wrappedValue.id, newValue: newValue)
            }
    }

    private func splitAmountDisplay(_ amount: Decimal) -> some View {
        CurrencyAmountInput(
            amount: .constant(formatEditableAmount(amount)),
            currencyCode: currencyCode
        )
        .fixedSize(horizontal: true, vertical: false)
        .allowsHitTesting(false)
    }

    private func maxAllowedForSplit(excluding id: UUID) -> Decimal {
        guard let total = totalAmount else { return 0 }
        let othersTotal = additionalSplits
            .filter { $0.id != id }
            .compactMap { CurrencyFormatter.parse($0.amountText) }
            .reduce(0, +)
        return max(0, total - othersTotal)
    }

    private func enforceSplitLimit(for splitID: UUID, newValue: String) {
        guard let parsed = CurrencyFormatter.parse(newValue) else { return }
        let maxAllowed = maxAllowedForSplit(excluding: splitID)
        guard parsed > maxAllowed,
              let index = additionalSplits.firstIndex(where: { $0.id == splitID }) else { return }
        additionalSplits[index].amountText = formatEditableAmount(maxAllowed)
    }

    private func clampAllSplitAmounts() {
        guard totalAmount != nil else { return }
        for split in additionalSplits {
            enforceSplitLimit(for: split.id, newValue: split.amountText)
        }
    }

    private func formatEditableAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = CurrencyFormatter.locale(for: currencyCode)
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    private var canSave: Bool {
        guard selectedAccount != nil, totalAmount != nil else { return false }
        if type == .transfer { return selectedToAccount != nil }

        if isSplitEnabled {
            guard selectedCategory != nil else { return false }
            guard primarySplitAmount >= 0 else { return false }
            guard additionalSplitTotal <= (totalAmount ?? 0) else { return false }
            guard splitCategoriesAreUnique else { return false }
            for split in additionalSplits {
                guard split.category != nil, CurrencyFormatter.parse(split.amountText) != nil else { return false }
            }
        }
        return true
    }

    private func loadTransaction() {
        guard let transaction else { return }
        title = transaction.title
        amountText = "\(transaction.amount)"
        type = transaction.type
        date = transaction.date
        note = transaction.note
        selectedAccount = transaction.account
        selectedToAccount = transaction.toAccount
        selectedCategory = transaction.category
        pendingAttachmentData = transaction.attachmentData

        let children = allTransactions.filter { $0.parentTransactionID == transaction.id }
        if !children.isEmpty {
            isSplitEnabled = true
            additionalSplits = children.map {
                SplitLine(category: $0.category, amountText: "\($0.amount)")
            }
        }
    }

    private func save() {
        guard let amount = totalAmount else { return }

        let target = transaction ?? Transaction(title: title, amount: amount, type: type, date: date)

        target.title = title
        target.amount = amount
        target.type = type
        target.date = date
        target.note = note
        target.account = selectedAccount
        target.toAccount = type == .transfer ? selectedToAccount : nil
        target.category = CategoryService.resolvedCategory(
            selectedCategory,
            for: type,
            context: dependencies.repository.context
        )
        target.attachmentData = pendingAttachmentData

        var splitLines: [(category: Category, amount: Decimal)] = []
        if isSplitEnabled && type != .transfer {
            for split in additionalSplits {
                guard let splitAmount = CurrencyFormatter.parse(split.amountText),
                      let category = split.category else { continue }
                splitLines.append((category, splitAmount))
            }
        }

        do {
            try dependencies.transactions.save(
                transaction: target,
                isNew: transaction == nil,
                splitLines: splitLines
            )
            Haptics.success()
            dismiss()
        } catch {}
    }

    private func deleteTransaction() {
        guard let transaction else { return }
        do {
            try dependencies.transactions.delete(transaction)
            Haptics.light()
            dismiss()
        } catch {}
    }

    private func processReceipt(_ image: UIImage) async {
        let scanner = ReceiptScanner()
        do {
            let text = try await scanner.recognizeText(from: image)
            let result = ReceiptParser.parse(text: text)
            let attachment = ReceiptScanSupport.jpegAttachment(from: image)
            let applied = ReceiptScanSupport.apply(
                result: result,
                categories: categories,
                attachmentData: attachment
            )
            await MainActor.run {
                if let total = applied.amountText { amountText = total }
                if let scannedDate = applied.date { date = scannedDate }
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let merchant = applied.title {
                    title = merchant
                }
                if selectedCategory == nil, let category = applied.category {
                    selectedCategory = category
                }
                if let attachment = applied.attachmentData {
                    pendingAttachmentData = attachment
                }
                if result.confidence < 0.5 {
                    receiptScanMessage = String(localized: "Double-check the amount and title — scans aren’t always perfect.")
                }
            }
        } catch {
            await MainActor.run {
                receiptScanMessage = String(localized: "Couldn’t read that receipt. Try better light, or type it in.")
            }
        }
    }
}
