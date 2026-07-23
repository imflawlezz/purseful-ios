import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) private var appState

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Budget.name) private var budgets: [Budget]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: \PlannedPayment.nextDueDate) private var plannedPayments: [PlannedPayment]
    @Query(sort: \Debt.createdAt) private var debts: [Debt]
    @Query(sort: \RecurringRule.startDate) private var recurringRules: [RecurringRule]
    @Query(sort: \ShoppingListItem.sortOrder) private var shoppingList: [ShoppingListItem]

    @State private var showJSONExporter = false
    @State private var exportDocument: ExportDocument?
    @State private var notificationsEnabled = false
    @State private var showClearDataAlert = false
    @State private var clearDataError: String?
    @State private var exportError: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountsListView()
                } label: {
                    settingsLabel("Accounts", systemImage: "creditcard.fill", tint: .blue)
                }
                NavigationLink {
                    CategoriesListView()
                } label: {
                    settingsLabel("Categories", systemImage: "tag.fill", tint: .orange)
                }
            } header: {
                AccentListSectionHeader(title: "Management")
            }
            .accentListRows()

            Section {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    settingsLabel("Appearance", systemImage: "paintbrush.fill", tint: .purple)
                }
                NavigationLink {
                    CurrencySettingsView()
                } label: {
                    settingsLabel("Currency", systemImage: "dollarsign.circle.fill", tint: .green)
                }
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingsLabel("Notifications", systemImage: "bell.badge.fill", tint: .red)
                }
            } header: {
                AccentListSectionHeader(title: "Preferences")
            }
            .accentListRows()

            Section {
                Button {
                    exportJSON()
                } label: {
                    settingsLabel("Export JSON", systemImage: "square.and.arrow.up.fill", tint: .indigo)
                }
                .foregroundStyle(.primary)
                NavigationLink {
                    JSONImportView()
                } label: {
                    settingsLabel("Import JSON", systemImage: "square.and.arrow.down.fill", tint: .teal)
                }
                NavigationLink {
                    PursefulWebImportView()
                } label: {
                    settingsLabel("Import Purseful Web Backup", systemImage: "globe", tint: .cyan)
                }
                Button(role: .destructive) {
                    showClearDataAlert = true
                } label: {
                    settingsLabel("Clear All Data", systemImage: "trash.fill", tint: .red)
                }
            } header: {
                AccentListSectionHeader(title: "Data")
            }
            .accentListRows()

            Section {
                LabeledContent {
                    Text(appVersionLabel)
                } label: {
                    settingsLabel("Version", systemImage: "info.circle.fill", tint: .gray)
                }
                HStack(spacing: 4) {
                    Text("Made with")
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("by")
                    Link("imflawlezz", destination: URL(string: "https://github.com/imflawlezz")!)
                }
                .font(.subheadline)
            } header: {
                AccentListSectionHeader(title: "About")
            }
            .accentListRows()
        }
        .accentTintedBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .fileExporter(
            isPresented: $showJSONExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "purseful-export"
        ) { _ in }
        .onAppear {
            SpotlightService.indexAll(transactions: transactions, accounts: accounts, categories: categories)
        }
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Clear All", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all accounts, transactions, budgets, goals, planned payments, debts, shopping list items, and other saved data. Default categories will be restored.")
        }
        .alert("Could Not Export", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert("Could Not Clear Data", isPresented: .init(
            get: { clearDataError != nil },
            set: { if !$0 { clearDataError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(clearDataError ?? "")
        }
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (Build \(build))"
    }

    private func settingsLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }

    private func clearAllData() {
        do {
            try dependencies.importExport.clearAllData()
            Haptics.success()
        } catch {
            clearDataError = error.localizedDescription
        }
    }

    private func exportJSON() {
        do {
            let data = try dependencies.importExport.exportJSON(
                transactions: transactions,
                accounts: accounts,
                categories: categories,
                budgets: budgets,
                goals: goals,
                plannedPayments: plannedPayments,
                debts: debts,
                recurringRules: recurringRules,
                shoppingList: shoppingList
            )
            exportDocument = ExportDocument(text: String(data: data, encoding: .utf8) ?? "")
            showJSONExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json, .commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct CurrencySettingsView: View {
    @State private var baseCurrency = AppSettings.shared.baseCurrency

    var body: some View {
        Form {
            Section {
                Picker("Base Currency", selection: $baseCurrency) {
                    ForEach(CommonCurrencies.codes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .onChange(of: baseCurrency) { _, newValue in
                    AppSettings.shared.baseCurrency = newValue
                }
                Text("All totals and reports use the base currency with live conversion rates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accentListRows()
        }
        .accentTintedBackground()
        .navigationTitle("Currency")
    }
}

struct AppearanceSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Text("Accent color tints interactive controls, screen backgrounds, and solid surfaces.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accentListRows()

            Section {
                ColorPickerGrid(selectedHex: $settings.accentColorHex)
                    .padding(.vertical, 4)
            } header: {
                AccentListSectionHeader(title: "Accent Color")
            }
            .accentListRows()
        }
        .accentTintedBackground()
        .id(settings.accentColorHex)
        .navigationTitle("Appearance")
    }
}

struct NotificationSettingsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var weeklySummary = AppSettings.shared.weeklySummaryEnabled
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                LabeledContent("Permission", value: authorizationLabel)
                Button("Request Notification Permission") {
                    Task {
                        _ = await NotificationService.shared.requestAuthorization()
                        await refreshAuthorizationStatus()
                        await NotificationScheduler.syncAll(context: dependencies.repository.context)
                    }
                }
            }
            .accentListRows()

            Section {
                Toggle("Weekly Summary", isOn: $weeklySummary)
                    .onChange(of: weeklySummary) { _, newValue in
                        AppSettings.shared.weeklySummaryEnabled = newValue
                        Task {
                            if newValue {
                                _ = await NotificationService.shared.requestAuthorization()
                                await refreshAuthorizationStatus()
                            }
                            await NotificationScheduler.syncAll(context: dependencies.repository.context)
                        }
                    }
                Text("Every Monday at 9:00 AM, receive a summary of spending from the previous 7 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accentListRows()
        }
        .accentTintedBackground()
        .navigationTitle("Notifications")
        .task {
            await refreshAuthorizationStatus()
        }
    }

    private var authorizationLabel: String {
        switch authorizationStatus {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not Requested"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await NotificationService.shared.authorizationStatus()
    }
}

struct AccountsListView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @State private var showAdd = false
    @State private var selectedAccount: Account?
    @State private var editMode: EditMode = .inactive

    private var visibleAccounts: [Account] {
        AccountPreferences.visibleAccounts(accounts)
    }

    var body: some View {
        List {
            ForEach(visibleAccounts) { account in
                accountRow(account)
                    .editDeleteSwipe(
                        onEdit: { selectedAccount = account },
                        onDelete: { delete(account) }
                    )
                    .rowContextMenu(preview: {
                        AccountDetailPreviewView(
                            account: account,
                            balance: BalanceCalculator.currentBalance(for: account, transactions: transactions)
                        )
                    }, actions: [
                        RowAction(id: "edit", title: "Edit", systemImage: "pencil") {
                            selectedAccount = account
                        },
                        RowAction(id: "delete", title: "Delete", systemImage: "trash", role: .destructive) {
                            delete(account)
                        }
                    ])
            }
            .onMove(perform: moveAccounts)
            .accentListRows()
        }
        .accentTintedBackground()
        .navigationTitle("Accounts")
        .environment(\.editMode, $editMode)
        .onAppear {
            AccountPreferences.ensureSortOrders(accounts: accounts, context: dependencies.repository.context)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editMode = editMode == .active ? .inactive : .active
                    }
                } label: {
                    Image(systemName: editMode == .active ? "checkmark" : "line.3.horizontal")
                }
                .accessibilityLabel(editMode == .active ? "Done" : "Reorder")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarIcon.add { showAdd = true }
            }
        }
        .accentSheet(isPresented: $showAdd) {
            AccountFormView()
        }
        .accentSheet(item: $selectedAccount) { account in
            AccountFormView(account: account)
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            AccountIconView(account: account)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.selectionLabel)
                Text(account.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if editMode == .active {
                Button {
                    setDefaultAccount(account)
                } label: {
                    Image(systemName: isDefaultAccount(account) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDefaultAccount(account) ? Color(hex: account.colorHex) : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDefaultAccount(account) ? "Default account" : "Set as default account")
            } else {
                Text(CurrencyFormatter.format(
                    BalanceCalculator.currentBalance(for: account, transactions: transactions),
                    currencyCode: account.currency
                ))
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard editMode == .inactive else { return }
            selectedAccount = account
        }
    }

    private func isDefaultAccount(_ account: Account) -> Bool {
        AppSettings.shared.defaultAccountID == account.id
    }

    private func setDefaultAccount(_ account: Account) {
        if isDefaultAccount(account) {
            AppSettings.shared.defaultAccountID = nil
        } else {
            AppSettings.shared.defaultAccountID = account.id
        }
        Haptics.light()
    }

    private func delete(_ account: Account) {
        AccountPreferences.clearDefaultIfNeeded(for: account)
        try? dependencies.accounts.delete(account)
        Haptics.light()
    }

    private func moveAccounts(from source: IndexSet, to destination: Int) {
        AccountPreferences.moveAccounts(
            from: source,
            to: destination,
            accounts: accounts,
            context: dependencies.repository.context
        )
    }
}

struct AccountFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    var account: Account?

    @State private var name = ""
    @State private var type: AccountType = .cash
    @State private var currency = AppSettings.shared.baseCurrency
    @State private var initialBalanceText = "0"
    @State private var colorHex = "#007AFF"
    @State private var icon = "banknote"
    @State private var includeInTotal = true

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(CommonCurrencies.codes, id: \.self) { Text($0).tag($0) }
                    }
                    LabeledAmountField(label: "Initial Balance", amount: $initialBalanceText, currencyCode: currency)
                    Toggle("Include in Net Worth", isOn: $includeInTotal)
                    SymbolPickerGrid(selectedSymbol: $icon)
                    ColorPickerGrid(selectedHex: $colorHex)
                }
                .accentListRows()
            }
            .dismissKeyboardOnTap()
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
            .accentTintedBackground()
            .toolbar {
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    showDelete: account != nil,
                    onDelete: account == nil ? nil : {
                        guard let account else { return }
                        AccountPreferences.clearDefaultIfNeeded(for: account)
                        try? dependencies.accounts.delete(account)
                        dismiss()
                    },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
            .onAppear {
                guard let account else { return }
                name = account.name
                type = account.type
                currency = account.currency
                initialBalanceText = "\(account.initialBalance)"
                colorHex = account.colorHex
                icon = account.icon
                includeInTotal = account.includeInTotal
            }
        }
    }

    private func save() {
        let balance = CurrencyFormatter.parse(initialBalanceText) ?? 0
        let target = account ?? Account(name: name)
        if account == nil {
            target.sortOrder = AccountPreferences.nextSortOrder(accounts: accounts)
        }
        target.name = name
        target.type = type
        target.currency = currency
        target.initialBalance = balance
        target.colorHex = colorHex
        target.icon = icon
        target.includeInTotal = includeInTotal
        target.updatedAt = Date()

        try? dependencies.accounts.save(target, isNew: account == nil)
        dismiss()
    }
}

struct CategoriesListView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var showAdd = false
    @State private var selectedCategory: Category?
    @State private var mergeSource: Category?
    @State private var mergeTarget: Category?
    @State private var showHiddenCategories = false

    private var listedCategories: [Category] {
        categories.filter { category in
            category.parent == nil && (showHiddenCategories || !category.isHidden)
        }
    }

    private var hiddenCategoryCount: Int {
        categories.filter { $0.isHidden }.count
    }

    var body: some View {
        List {
            if hiddenCategoryCount > 0 {
                Section {
                    Toggle("Show Hidden", isOn: $showHiddenCategories)
                }
                .accentListRows()
            }

            ForEach(listedCategories) { category in
                Section {
                    categoryRow(category)
                    ForEach(category.children?.filter { showHiddenCategories || !$0.isHidden } ?? []) { child in
                        categoryRow(child)
                            .padding(.leading, 8)
                    }
                } header: {
                    AccentListSectionHeader(title: category.name)
                }
                .accentListRows()
            }
        }
        .accentTintedBackground()
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarIcon.add { showAdd = true }
            }
        }
        .accentSheet(isPresented: $showAdd) {
            CategoryFormView()
        }
        .accentSheet(item: $selectedCategory) { category in
            CategoryEditView(category: category)
        }
        .accentSheet(item: $mergeSource) { source in
            CategoryMergeView(source: source, categories: categories)
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack {
            CategoryIconView(category: category)
            Text(category.name)
                .foregroundStyle(Color(hex: category.colorHex))
            if category.isHidden {
                Text("Hidden")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
            if category.isSystem {
                Text("System")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCategory = category
        }
        .rowContextMenu(preview: {
            CategoryDetailPreviewView(category: category)
        }, actions: categoryRowActions(category))
        .swipeActions(edge: .leading) {
            Button {
                category.isHidden.toggle()
                try? dependencies.categories.save(category, isNew: false)
            } label: {
                Image(systemName: category.isHidden ? "eye" : "eye.slash")
            }
            .tint(.orange)
            .accessibilityLabel(category.isHidden ? "Show" : "Hide")
        }
        .swipeActions(edge: .trailing) {
            Button {
                selectedCategory = category
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.blue)
            .accessibilityLabel("Edit")

            if !category.isSystem {
                Button {
                    mergeSource = category
                } label: {
                    Image(systemName: "arrow.triangle.merge")
                }
                .tint(.indigo)
                .accessibilityLabel("Merge")

                Button(role: .destructive) {
                    deleteCategory(category)
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel("Delete")
            }
        }
    }

    private func categoryRowActions(_ category: Category) -> [RowAction] {
        var actions: [RowAction] = [
            RowAction(id: "edit", title: "Edit", systemImage: "pencil") {
                selectedCategory = category
            },
            RowAction(
                id: "hide",
                title: category.isHidden ? "Show" : "Hide",
                systemImage: category.isHidden ? "eye" : "eye.slash"
            ) {
                category.isHidden.toggle()
                try? dependencies.categories.save(category, isNew: false)
            }
        ]

        if !category.isSystem {
            actions.append(RowAction(id: "merge", title: "Merge", systemImage: "arrow.triangle.merge") {
                mergeSource = category
            })
            actions.append(RowAction(id: "delete", title: "Delete", systemImage: "trash", role: .destructive) {
                deleteCategory(category)
            })
        }

        return actions
    }

    private func deleteCategory(_ category: Category) {
        guard !category.isSystem else { return }
        try? dependencies.categories.delete(category)
        Haptics.light()
    }
}

struct CategoryFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex = "#8E8E93"
    @State private var type: CategoryType = .expense
    @State private var parent: Category?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(CategoryType.expense)
                        Text("Income").tag(CategoryType.income)
                    }
                    Picker("Parent", selection: $parent) {
                        Text("None").tag(Optional<Category>.none)
                        ForEach(categories.filter { $0.parent == nil && !$0.isHidden }) { category in
                            CategoryNameLabel.picker(category: category).tag(Optional(category))
                        }
                    }
                    SymbolPickerGrid(selectedSymbol: $icon)
                    ColorPickerGrid(selectedHex: $colorHex)
                }
                .accentListRows()
            }
            .dismissKeyboardOnTap()
            .navigationTitle("New Category")
            .accentTintedBackground()
            .toolbar {
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
        }
    }

    private func save() {
        let category = Category(name: name, icon: icon, colorHex: colorHex, type: type, parent: parent)
        try? dependencies.categories.save(category, isNew: true)
        dismiss()
    }
}

struct CategoryEditView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: Category

    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex = "#8E8E93"
    @State private var type: CategoryType = .expense

    private var canSave: Bool {
        category.isSystem || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if category.isSystem {
                        LabeledContent("Name", value: category.name)
                        LabeledContent("Type", value: category.type == .income ? "Income" : "Expense")
                        Text("System categories keep their name and type, but you can customize the icon and color.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Name", text: $name)
                        Picker("Type", selection: $type) {
                            Text("Expense").tag(CategoryType.expense)
                            Text("Income").tag(CategoryType.income)
                        }
                    }
                    SymbolPickerGrid(selectedSymbol: $icon)
                    ColorPickerGrid(selectedHex: $colorHex)
                }
                .accentListRows()
            }
            .navigationTitle("Edit Category")
            .accentTintedBackground()
            .toolbar {
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    showDelete: !category.isSystem,
                    onDelete: category.isSystem ? nil : {
                        try? dependencies.categories.delete(category)
                        dismiss()
                    },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
            .onAppear {
                name = category.name
                icon = category.icon
                colorHex = category.colorHex
                type = category.type
            }
        }
    }

    private func save() {
        if !category.isSystem {
            category.name = name
            category.type = type
        }
        category.icon = icon
        category.colorHex = colorHex
        try? dependencies.categories.save(category, isNew: false)
        dismiss()
    }
}

struct CategoryMergeView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let source: Category
    let categories: [Category]
    @State private var target: Category?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Merge \"\(source.name)\" into:")
                    Picker("Target Category", selection: $target) {
                        ForEach(categories.filter { $0.id != source.id && !$0.isHidden }) { category in
                            CategoryNameLabel.picker(category: category).tag(Optional(category))
                        }
                    }
                }
                .accentListRows()
            }
            .navigationTitle("Merge Category")
            .accentTintedBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIcon.cancel { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarIcon.confirm(
                        { merge() },
                        systemImage: "arrow.triangle.merge",
                        label: "Merge",
                        disabled: target == nil
                    )
                }
            }
        }
    }

    private func merge() {
        guard let target else { return }
        try? dependencies.categories.merge(source: source, into: target)
        dismiss()
    }
}
