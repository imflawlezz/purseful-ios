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
        .listSectionSpacing(24)
        .navigationTitle("Import Backup (Legacy)")
        .navigationBarTitleDisplayMode(.inline)
        .accentTintedBackground()
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
        .alert("Import failed", isPresented: .init(
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
                Toggle("Keep my existing data", isOn: $mergeExisting)
            } header: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Restore a backup from legacy Purseful website.")
                    Link(destination: URL(string: "https://purseful-app.vercel.app/")!) {
                        HStack(spacing: 4) {
                            Text("purseful-app.vercel.app")
                                .underline()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(AppSettings.shared.accentColor)
                    Text("You will be prompted to match accounts and categories before importing.")
                }
                .font(.body)
                .foregroundStyle(.primary)
                .textCase(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)
                .clearListSupplementaryBackground()
            }
            .accentListRows()

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
            .accentListRows()

            if backup != nil {
                Section {
                    Button("Continue to accounts") {
                        step = .mapAccounts
                    }
                }
                .accentListRows()
            }
        }
    }

    @ViewBuilder
    private var accountMappingSection: some View {
        Section {
            Text("For each account in the backup, pick which of yours it should become.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accentListRows()

        ForEach(backup?.accounts ?? []) { webAccount in
            Section {
                Picker("Import as", selection: accountBinding(for: webAccount.id)) {
                    Text("Create new account")
                        .tag(PursefulWebImportService.MappingTarget.createNew)

                    ForEach(accounts.filter { !$0.isHidden }) { account in
                        Text(account.selectionLabel)
                            .tag(PursefulWebImportService.MappingTarget.existing(account.id))
                    }
                }
                .pickerStyle(.navigationLink)

                LabeledContent("Old type", value: webAccount.type.capitalized)
                LabeledContent("Currency", value: webAccount.currency)
            } header: {
                AccentListSectionHeader(title: webAccount.name)
            }
            .accentListRows()
        }
    }

    @ViewBuilder
    private var categoryMappingSection: some View {
        Section {
            Text("Match each category from the backup to one of yours. Only the same type is shown—income or expense.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accentListRows()

        ForEach(backup?.categories ?? []) { webCategory in
            Section {
                Picker("Import as", selection: categoryBinding(for: webCategory.id)) {
                    Text("Create new category")
                        .tag(PursefulWebImportService.MappingTarget.createNew)

                    ForEach(selectableCategories(for: webCategory)) { category in
                        Text(category.name.localizedDisplayName)
                            .tag(PursefulWebImportService.MappingTarget.existing(category.id))
                    }
                }
                .pickerStyle(.navigationLink)

                LabeledContent("field.type", value: webCategory.type.capitalized)
            } header: {
                AccentListSectionHeader(title: webCategory.name)
            }
            .accentListRows()
        }
    }

    private var importSection: some View {
        Group {
            Section {
                LabeledContent("Accounts mapped", value: "\(mappings.accounts.count)")
                LabeledContent("Categories mapped", value: "\(mappings.categories.count)")
                LabeledContent("Transactions to import", value: "\(backup?.transactions?.count ?? 0)")
            } header: {
                AccentListSectionHeader(title: "Summary")
            }
            .accentListRows()

            Section {
                FormActionButton(
                    title: isImporting ? String(localized: "Importing…") : String(localized: "Import backup"),
                    systemImage: "square.and.arrow.down"
                ) {
                    runImport()
                }
                .disabled(isImporting || backup == nil || backupData == nil)
            }
            .accentListRows()

            if let importResult {
                Section {
                    LabeledContent("Accounts linked", value: "\(importResult.accounts)")
                    LabeledContent("Categories linked", value: "\(importResult.categories)")
                    LabeledContent("Transactions imported", value: "\(importResult.transactions)")
                    if importResult.skippedDuplicates > 0 {
                        LabeledContent("Skipped duplicates", value: "\(importResult.skippedDuplicates)")
                    }
                    if importResult.skippedInvalid > 0 {
                        LabeledContent("Skipped bad rows", value: "\(importResult.skippedInvalid)")
                    }
                } header: {
                    AccentListSectionHeader(title: "Last import")
                }
                .accentListRows()
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
            importError = String(localized: "Couldn’t open that file.")
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
