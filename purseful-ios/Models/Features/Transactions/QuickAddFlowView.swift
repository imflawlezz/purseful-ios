import SwiftData
import SwiftUI

struct QuickAddFlowView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var title = ""
    @State private var selectedAccount: Account?
    @State private var selectedCategory: Category?
    @State private var step: Step = .account
    @State private var showScanner = false
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var pendingAttachmentData: Data?
    @State private var receiptScanMessage: String?

    private enum Step {
        case account, amount, category
    }

    private var amountCurrencyCode: String {
        selectedAccount?.currency ?? AppSettings.shared.baseCurrency
    }

    private var amountIsValid: Bool {
        CurrencyFormatter.parse(amountText) != nil
    }

    var body: some View {
        Group {
            switch step {
            case .account:
                accountStep
            case .amount:
                amountStep
            case .category:
                categoryStep
            }
        }
        .navigationTitle(stepTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accentTintedBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if step == .account {
                    ToolbarIcon.cancel { dismiss() }
                } else {
                    ToolbarIcon.back { goBack() }
                }
            }
            if step == .amount {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }
                    .accessibilityLabel(String(localized: "Scan receipt"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        step = .category
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!amountIsValid)
                    .accessibilityLabel(String(localized: "Continue"))
                }
            }
        }
        .presentationDetents([.fraction(0.36), .medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: step) { _, newStep in
            withAnimation(.snappy) {
                sheetDetent = detent(for: newStep)
            }
        }
        .scrollDismissesKeyboard(.interactively)
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

    private var stepTitle: String {
        switch step {
        case .account: String(localized: "Quick add")
        case .amount: String(localized: "Quick add")
        case .category: String(localized: "Category")
        }
    }

    private func detent(for step: Step) -> PresentationDetent {
        switch step {
        case .account: .medium
        case .amount: .fraction(0.36)
        case .category: .large
        }
    }

    private var amountStep: some View {
        VStack(spacing: 16) {
            Picker("field.type", selection: $type) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            amountGlassBubble
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var amountGlassBubble: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(amountCurrencyCode)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(minWidth: 72)
                    .textFieldStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .pursefulGlass(in: Capsule(style: .continuous), interactive: true)
    }

    private var categoryStep: some View {
        List {
            Section {
                ForEach(categoryTree) { item in
                    categoryRow(item.category, depth: item.depth)
                }
            }
            .accentListRows()
        }
        .listStyle(.insetGrouped)
    }

    private var accountStep: some View {
        List {
            Section {
                ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                    Button {
                        selectedAccount = account
                        step = .amount
                    } label: {
                        AccountPickerRow(account: account)
                    }
                    .buttonStyle(.plain)
                }
            }
            .accentListRows()
        }
        .listStyle(.insetGrouped)
        .onAppear {
            if selectedAccount == nil {
                selectedAccount = AccountPreferences.preferredAccount(from: accounts)
                if selectedAccount != nil {
                    step = .amount
                }
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: Category, depth: Int) -> some View {
        Button {
            selectedCategory = category
            if title.isEmpty {
                title = category.name
            }
            save()
        } label: {
            CategoryPickerRow(category: category, depth: depth)
        }
        .buttonStyle(.plain)
    }

    private struct CategoryTreeItem: Identifiable {
        let id: UUID
        let category: Category
        let depth: Int

        init(category: Category, depth: Int) {
            self.id = category.id
            self.category = category
            self.depth = depth
        }
    }

    private var categoryTree: [CategoryTreeItem] {
        let categoryType: CategoryType = type == .income ? .income : .expense
        let filtered = Category.userSelectable(categories, type: categoryType)
        let parents = filtered.filter { $0.parent == nil }.sorted { $0.sortOrder < $1.sortOrder }
        var items: [CategoryTreeItem] = []

        for parent in parents {
            items.append(CategoryTreeItem(category: parent, depth: 0))
            let children = filtered
                .filter { $0.parent?.id == parent.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            for child in children {
                items.append(CategoryTreeItem(category: child, depth: 1))
            }
        }
        return items
    }

    private func goBack() {
        switch step {
        case .amount: step = .account
        case .category: step = .amount
        case .account: break
        }
    }

    private func save() {
        guard let account = selectedAccount,
              let amount = CurrencyFormatter.parse(amountText) else { return }
        let transaction = Transaction(
            title: title.isEmpty ? (selectedCategory?.name ?? type.displayName) : title,
            amount: amount,
            type: type,
            account: account,
            category: selectedCategory,
            attachmentData: pendingAttachmentData
        )
        try? dependencies.transactions.save(transaction: transaction, isNew: true, splitLines: [])
        Haptics.success()
        dismiss()
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
                if let merchant = applied.title { title = merchant }
                if let category = applied.category { selectedCategory = category }
                if let attachment = applied.attachmentData { pendingAttachmentData = attachment }
                type = .expense
                if result.confidence < 0.5 {
                    receiptScanMessage = String(localized: "Double-check the amount — scans aren’t always perfect.")
                }
            }
        } catch {
            await MainActor.run {
                receiptScanMessage = String(localized: "Couldn’t read that receipt. Try better light, or type it in.")
            }
        }
    }
}
