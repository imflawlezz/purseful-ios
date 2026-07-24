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
                Text("Restore a Purseful backup—accounts, transactions, budgets, goals, and more. Merge keeps your current settings; otherwise the file’s settings are used.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accentListRows()

            Section {
                Toggle("Keep my existing data", isOn: $mergeExisting)
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
                    LabeledContent("Planned payments", value: "\(importResult.plannedPayments)")
                    LabeledContent("Debts", value: "\(importResult.debts)")
                    LabeledContent("Recurring rules", value: "\(importResult.recurringRules)")
                    LabeledContent("Shopping list", value: "\(importResult.shoppingList)")
                    if importResult.skippedDuplicates > 0 {
                        LabeledContent("Skipped duplicates", value: "\(importResult.skippedDuplicates)")
                    }
                } header: {
                    AccentListSectionHeader(title: "Last import")
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
        .alert("Import failed", isPresented: .init(
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
            importError = String(localized: "Couldn’t open that file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard ImportService.isAppExport(data) else {
                importError = String(localized: "This isn’t a Purseful export. For old website backups, use Web backup import.")
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
        dependencies.importExport.syncWidgets()
    }
}
