import SwiftData
import SwiftUI

private enum TransactionRoute: Hashable {
    case add
    case detail(UUID)
}

struct TransactionsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState
    @State private var historyStart = Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? Date()
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @State private var showFilters = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedIDs = Set<UUID>()

    @State private var filterAccount: Account?
    @State private var filterCategory: Category?
    @State private var filterType: TransactionType?
    @State private var sortOption: TransactionSortOption = .dateDescending

    private var queryStart: Date {
        let needsFullHistory = !searchText.isEmpty
            || filterAccount != nil
            || filterCategory != nil
            || filterType != nil
            || sortOption != .dateDescending
        return needsFullHistory ? .distantPast : historyStart
    }

    var body: some View {
        DatedTransactionQuery(start: queryStart) { loaded in
            transactionBrowser(allTransactions: loaded)
        }
    }

    private func visibleTransactions(from loaded: [Transaction]) -> [Transaction] {
        var result = loaded.filter { !$0.isSplitChild }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.note.localizedCaseInsensitiveContains(searchText)
                || ($0.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
                || "\($0.amount)".contains(searchText)
            }
        }
        if let filterAccount { result = result.filter { $0.account?.id == filterAccount.id } }
        if let filterCategory { result = result.filter { $0.category?.id == filterCategory.id } }
        if let filterType { result = result.filter { $0.type == filterType } }

        switch sortOption {
        case .dateDescending: result.sort { $0.date > $1.date }
        case .dateAscending: result.sort { $0.date < $1.date }
        case .amountDescending: result.sort { $0.amount > $1.amount }
        case .amountAscending: result.sort { $0.amount < $1.amount }
        case .category: result.sort { ($0.category?.name ?? "") < ($1.category?.name ?? "") }
        }
        return result
    }

    private func groupedTransactions(from loaded: [Transaction]) -> [(day: Date, items: [Transaction], total: Decimal)] {
        let calendar = Calendar.current
        let baseCurrency = AppSettings.shared.baseCurrency
        let rates = appState.resolvedExchangeRates()
        let grouped = Dictionary(grouping: visibleTransactions(from: loaded)) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            let items = grouped[day] ?? []
            let total = BalanceCalculator.dayNetCashFlow(
                transactions: items,
                baseCurrency: baseCurrency,
                exchangeRates: rates
            )
            return (day, items, total)
        }
    }

    @ViewBuilder
    private func transactionBrowser(allTransactions: [Transaction]) -> some View {
        let groups = groupedTransactions(from: allTransactions)
        NavigationStack(path: $navigationPath) {
            Group {
                if groups.isEmpty {
                    EmptyStateView(
                        title: String(localized: "No transactions"),
                        systemImage: "list.bullet.rectangle",
                        message: String(localized: "Tap + to add one.")
                    )
                } else {
                    List {
                        ForEach(groups, id: \.day) { group in
                            Section {
                                ForEach(group.items) { transaction in
                                    transactionRow(transaction)
                                }
                                .accentListRows()
                            } header: {
                                HStack {
                                    Text(DateFormatters.dayHeader.string(from: group.day))
                                    Spacer()
                                    Text(CurrencyFormatter.format(group.total, currencyCode: AppSettings.shared.baseCurrency))
                                        .font(.caption)
                                }
                                .clearListSectionHeaderBackground()
                            }
                            .onAppear {
                                if group.day == groups.last?.day {
                                    loadEarlierHistory()
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(nil, value: editMode)
                    .onTabScrollToTop(1)
                }
            }
            .accentTintedBackground()
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        editMode = editMode == .active ? .inactive : .active
                        if editMode == .inactive { selectedIDs.removeAll() }
                    } label: {
                        Image(systemName: editMode == .active ? "checkmark.circle.badge.xmark" : "checkmark.circle.dotted")
                    }
                    .accessibilityLabel(editMode == .active ? String(localized: "Done") : String(localized: "Select"))
                }
                if editMode == .active && !selectedIDs.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            batchDelete(from: allTransactions)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(String(localized: "Delete selected"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel(String(localized: "Filters"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        navigationPath.append(TransactionRoute.add)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(String(localized: "Add transaction"))
                }
            }
            .navigationDestination(for: TransactionRoute.self) { route in
                switch route {
                case .add:
                    TransactionFormView()
                case .detail(let id):
                    TransactionFormLoader(id: id, fallback: allTransactions.first(where: { $0.id == id }))
                }
            }
            .accentSheet(isPresented: $showFilters) {
                TransactionFiltersView(
                    filterAccount: $filterAccount,
                    filterCategory: $filterCategory,
                    filterType: $filterType,
                    sortOption: $sortOption,
                    accounts: accounts,
                    categories: categories
                )
            }
            .onChange(of: appState.pendingTransactionID) { _, transactionID in
                guard let transactionID else { return }
                navigationPath.append(TransactionRoute.detail(transactionID))
                appState.pendingTransactionID = nil
            }
            .onChange(of: appState.pendingCategoryID) { _, categoryID in
                guard let categoryID else { return }
                filterCategory = categories.first { $0.id == categoryID }
                appState.pendingCategoryID = nil
            }
            .onChange(of: appState.tabScrollToken(for: 1)) { _, _ in
                navigationPath = NavigationPath()
            }
        }
    }

    @ViewBuilder
    private func transactionRow(_ transaction: Transaction) -> some View {
        if editMode == .active {
            Button {
                toggleSelection(transaction.id)
            } label: {
                transactionRowContent(transaction)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: TransactionRoute.detail(transaction.id)) {
                transactionRowContent(transaction)
            }
            .buttonStyle(.plain)
            .editDeleteSwipe(
                onEdit: { navigationPath.append(TransactionRoute.detail(transaction.id)) },
                onDelete: { delete(transaction) }
            )
            .rowContextMenu(preview: {
                TransactionDetailPreviewView(transaction: transaction)
            }, actions: [
                RowAction(id: "edit", title: String(localized: "Edit"), systemImage: "pencil") {
                    navigationPath.append(TransactionRoute.detail(transaction.id))
                },
                RowAction(id: "delete", title: String(localized: "Delete"), systemImage: "trash", role: .destructive) {
                    delete(transaction)
                }
            ])
        }
    }

    private func transactionRowContent(_ transaction: Transaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedIDs.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selectedIDs.contains(transaction.id) ? Color.accentColor : Color.secondary)
                .contentTransition(.identity)
                .opacity(editMode == .active ? 1 : 0)
                .frame(width: editMode == .active ? 24 : 0)
                .clipped()
                .allowsHitTesting(false)
                .animation(nil, value: selectedIDs.contains(transaction.id))
                .animation(nil, value: editMode)

            TransactionRowView(
                transaction: transaction,
                baseCurrency: AppSettings.shared.baseCurrency
            )
        }
        .contentShape(Rectangle())
    }

    private func loadEarlierHistory() {
        guard queryStart > Date.distantPast else { return }
        historyStart = Calendar.current.date(byAdding: .day, value: -45, to: historyStart) ?? historyStart
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func delete(_ transaction: Transaction) {
        try? dependencies.transactions.delete(transaction)
        Haptics.light()
    }

    private func batchDelete(from loaded: [Transaction]) {
        let toDelete = loaded.filter { selectedIDs.contains($0.id) }
        try? dependencies.transactions.deleteMany(toDelete)
        selectedIDs.removeAll()
        editMode = .inactive
    }
}

private struct TransactionFormLoader: View {
    let id: UUID
    let fallback: Transaction?
    @Query private var matches: [Transaction]

    init(id: UUID, fallback: Transaction?) {
        self.id = id
        self.fallback = fallback
        let captured = id
        _matches = Query(filter: #Predicate<Transaction> { $0.id == captured })
    }

    var body: some View {
        if let transaction = matches.first ?? fallback {
            TransactionFormView(transaction: transaction)
        }
    }
}

struct TransactionFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterAccount: Account?
    @Binding var filterCategory: Category?
    @Binding var filterType: TransactionType?
    @Binding var sortOption: TransactionSortOption
    let accounts: [Account]
    let categories: [Category]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Account", selection: $filterAccount) {
                        Text("All").tag(Optional<Account>.none)
                        ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                            Text(account.selectionLabel).tag(Optional(account))
                        }
                    }
                    Picker("Category", selection: $filterCategory) {
                        Text("All").tag(Optional<Category>.none)
                        ForEach(Category.userSelectable(categories.filter { !$0.isHidden })) { category in
                            CategoryNameLabel.picker(category: category).tag(Optional(category))
                        }
                    }
                    Picker("field.type", selection: $filterType) {
                        Text("All").tag(Optional<TransactionType>.none)
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(Optional(type))
                        }
                    }
                    Picker("Sort", selection: $sortOption) {
                        ForEach(TransactionSortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
                .accentListRows()
            }
            .navigationTitle("Filters")
            .accentTintedBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarIcon.done { dismiss() }
                }
            }
        }
    }
}
