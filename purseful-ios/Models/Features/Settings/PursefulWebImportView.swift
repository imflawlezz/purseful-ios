import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PursefulWebImportView: View {
    private enum Step: Int, CaseIterable {
        case setup
        case mapAccounts
        case mapCategories
        case importBackup
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var step: Step = .setup
    @State private var showImporter = false
    @State private var mergeExisting = true
    @State private var backupData: Data?
    @State private var backup: PursefulWebImportService.WebBackup?
    @State private var mappings = PursefulWebImportService.ImportMappings()
    @State private var importResult: PursefulWebImportService.ImportResult?
    @State private var importError: String?
    @State private var isImporting = false

    var body: some View {
        Form {
            switch step {
            case .setup:
                setupSection
            case .mapAccounts:
                accountMappingSection
            case .mapCategories:
                categoryMappingSection
            case .importBackup:
                importSection
            }
        }
        .navigationTitle("Purseful Web Import")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarIcon.back {
                    if step == .setup {
                        dismiss()
                    } else {
                        goBack()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if step == .mapAccounts || step == .mapCategories {
                    ToolbarIcon.done { goForward() }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                loadBackup(from: url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Failed", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private var setupSection: some View {
        Group {
            Section {
                Text("Import a JSON backup from legacy Purseful Web. You’ll map each legacy account and category to an existing one, or create new records. Account balances are reconciled using the backup snapshot and an opening balance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Merge with existing data", isOn: $mergeExisting)
                if mergeExisting {
                    Text("Re-importing the same backup skips transactions already imported. For a clean migration, turn this off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Choose Backup File") {
                    showImporter = true
                }

                if let backup {
                    LabeledContent("Accounts in backup", value: "\(backup.accounts?.count ?? 0)")
                    LabeledContent("Categories in backup", value: "\(backup.categories?.count ?? 0)")
                    LabeledContent("Transactions in backup", value: "\(backup.transactions?.count ?? 0)")
                }
            }

            if backup != nil {
                Section {
                    Button("Continue to Account Mapping") {
                        step = .mapAccounts
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accountMappingSection: some View {
        Section {
            Text("Choose which existing account each legacy account should use.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        ForEach(backup?.accounts ?? []) { webAccount in
            Section(webAccount.name) {
                Picker("Import as", selection: accountBinding(for: webAccount.id)) {
                    Text("Create new account")
                        .tag(PursefulWebImportService.MappingTarget.createNew)

                    ForEach(accounts.filter { !$0.isHidden }) { account in
                        Text(account.selectionLabel)
                            .tag(PursefulWebImportService.MappingTarget.existing(account.id))
                    }
                }
                .pickerStyle(.navigationLink)

                LabeledContent("Legacy type", value: webAccount.type.capitalized)
                LabeledContent("Currency", value: webAccount.currency)
            }
        }
    }

    @ViewBuilder
    private var categoryMappingSection: some View {
        Section {
            Text("Map legacy categories to your existing ones. Only categories of the same type are suggested.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        ForEach(backup?.categories ?? []) { webCategory in
            Section(webCategory.name) {
                Picker("Import as", selection: categoryBinding(for: webCategory.id)) {
                    Text("Create new category")
                        .tag(PursefulWebImportService.MappingTarget.createNew)

                    ForEach(selectableCategories(for: webCategory)) { category in
                        Text(category.name)
                            .tag(PursefulWebImportService.MappingTarget.existing(category.id))
                    }
                }
                .pickerStyle(.navigationLink)

                LabeledContent("Type", value: webCategory.type.capitalized)
            }
        }
    }

    private var importSection: some View {
        Group {
            Section("Summary") {
                LabeledContent("Accounts mapped", value: "\(mappings.accounts.count)")
                LabeledContent("Categories mapped", value: "\(mappings.categories.count)")
                LabeledContent("Transactions to import", value: "\(backup?.transactions?.count ?? 0)")
            }

            Section {
                FormActionButton(
                    title: isImporting ? "Importing…" : "Import Backup",
                    systemImage: "square.and.arrow.down"
                ) {
                    runImport()
                }
                .disabled(isImporting || backup == nil || backupData == nil)
            }

            if let importResult {
                Section("Last Import") {
                    LabeledContent("Accounts linked", value: "\(importResult.accounts)")
                    LabeledContent("Categories linked", value: "\(importResult.categories)")
                    LabeledContent("Transactions imported", value: "\(importResult.transactions)")
                    if importResult.skippedDuplicates > 0 {
                        LabeledContent("Skipped duplicates", value: "\(importResult.skippedDuplicates)")
                    }
                    if importResult.skippedInvalid > 0 {
                        LabeledContent("Skipped invalid rows", value: "\(importResult.skippedInvalid)")
                    }
                }
            }
        }
    }

    private func accountBinding(for webID: String) -> Binding<PursefulWebImportService.MappingTarget> {
        Binding(
            get: { mappings.accounts[webID] ?? .createNew },
            set: { mappings.accounts[webID] = $0 }
        )
    }

    private func categoryBinding(for webID: String) -> Binding<PursefulWebImportService.MappingTarget> {
        Binding(
            get: { mappings.categories[webID] ?? .createNew },
            set: { mappings.categories[webID] = $0 }
        )
    }

    private func selectableCategories(for webCategory: PursefulWebImportService.WebCategory) -> [Category] {
        let type: CategoryType = webCategory.type == "income" ? .income : .expense
        return Category.userSelectable(categories, type: type)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Could not access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try PursefulWebImportService.parseBackup(data: data)
            backupData = data
            backup = parsed
            mappings = PursefulWebImportService.suggestedMappings(
                backup: parsed,
                existingAccounts: accounts,
                existingCategories: categories
            )
            importResult = nil
            step = .setup
        } catch {
            importError = error.localizedDescription
        }
    }

    private func goBack() {
        switch step {
        case .mapAccounts:
            step = .setup
        case .mapCategories:
            step = .mapAccounts
        case .importBackup:
            step = .mapCategories
        case .setup:
            break
        }
    }

    private func goForward() {
        switch step {
        case .setup:
            step = .mapAccounts
        case .mapAccounts:
            step = .mapCategories
        case .mapCategories:
            step = .importBackup
        case .importBackup:
            break
        }
    }

    private func runImport() {
        guard let backup else { return }
        isImporting = true

        do {
            importResult = try PursefulWebImportService.importBackup(
                backup: backup,
                context: modelContext,
                merge: mergeExisting,
                mappings: mappings
            )
            Haptics.success()
        } catch {
            importError = error.localizedDescription
        }

        isImporting = false
    }
}
