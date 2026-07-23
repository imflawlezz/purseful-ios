import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct JSONImportView: View {
    @Environment(DependencyContainer.self) private var dependencies

    @State private var showImporter = false
    @State private var mergeExisting = true
    @State private var importResult: ImportService.ImportResult?
    @State private var importError: String?

    var body: some View {
        Form {
            Section {
                Text("Import a Purseful JSON export file. Accounts, categories, transactions, budgets, goals, planned payments, debts, shopping list, and app preferences are restored. Merge keeps your current settings; replace applies exported preferences.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accentListRows()

            Section {
                Toggle("Merge with existing data", isOn: $mergeExisting)
            }
            .accentListRows()

            Section {
                Button("Choose JSON File") {
                    showImporter = true
                }
            }
            .accentListRows()

            if let importResult {
                Section {
                    LabeledContent("Accounts", value: "\(importResult.accounts)")
                    LabeledContent("Categories", value: "\(importResult.categories)")
                    LabeledContent("Transactions", value: "\(importResult.transactions)")
                    LabeledContent("Budgets", value: "\(importResult.budgets)")
                    LabeledContent("Goals", value: "\(importResult.goals)")
                    LabeledContent("Planned Payments", value: "\(importResult.plannedPayments)")
                    LabeledContent("Debts", value: "\(importResult.debts)")
                    LabeledContent("Recurring Rules", value: "\(importResult.recurringRules)")
                    LabeledContent("Shopping List", value: "\(importResult.shoppingList)")
                    if importResult.skippedDuplicates > 0 {
                        LabeledContent("Skipped duplicates", value: "\(importResult.skippedDuplicates)")
                    }
                } header: {
                    AccentListSectionHeader(title: "Last Import")
                }
                .accentListRows()
            }
        }
        .navigationTitle("Import JSON")
        .navigationBarTitleDisplayMode(.inline)
        .accentTintedBackground()
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importJSON(from: url)
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

    private func importJSON(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Could not access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard ImportService.isAppExport(data) else {
                importError = "This file is not a Purseful app export. Use Purseful Web Import for legacy web backups."
                return
            }
            importResult = try dependencies.importExport.importJSON(
                data: data,
                merge: mergeExisting
            )
            syncWidgets()
            Haptics.success()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func syncWidgets() {
        let accounts = (try? dependencies.repository.fetch(FetchDescriptor<Account>())) ?? []
        let transactions = (try? dependencies.repository.fetch(FetchDescriptor<Transaction>())) ?? []
        let budgets = (try? dependencies.repository.fetch(FetchDescriptor<Budget>())) ?? []
        dependencies.importExport.syncWidgets(accounts: accounts, transactions: transactions, budgets: budgets)
    }
}
