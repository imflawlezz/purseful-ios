import SwiftData
import SwiftUI

struct ShoppingListView: View {
    private enum FocusField: Hashable {
        case draft
        case item(UUID)
    }

    @Environment(DependencyContainer.self) private var dependencies
    @Query(sort: \ShoppingListItem.sortOrder) private var items: [ShoppingListItem]

    @State private var draftText = ""
    @State private var focusRequest: FocusField?
    @FocusState private var focusedField: FocusField?

    private var currencyCode: String { AppSettings.shared.baseCurrency }

    private var listTotal: Decimal {
        items.compactMap(\.lineTotal).reduce(0, +)
    }

    private var selectionTotal: Decimal {
        items.filter(\.isChecked).compactMap(\.lineTotal).reduce(0, +)
    }

    var body: some View {
        List {
            ForEach(items) { item in
                if item.isParsed {
                    parsedRow(item)
                } else {
                    textRow(item)
                }
            }
            .onDelete(perform: deleteItems)

            TextField("Start typing…", text: $draftText, axis: .vertical)
                .lineLimit(1...4)
                .focused($focusedField, equals: .draft)
                .textInputAutocapitalization(.sentences)
                .onChange(of: draftText) { _, newValue in
                    handleDraftChange(newValue)
                }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    clearList()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(items.isEmpty)
                .accessibilityLabel("Clear list")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            totalsFooter
        }
        .onChange(of: focusedField) { previous, _ in
            commitFocusChange(from: previous)
        }
        .onDisappear {
            commitDraft()
            if case .item(let id) = focusedField {
                commitTextItem(id: id)
            }
        }
    }

    private var totalsFooter: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("List total")
                    Spacer()
                    Text(CurrencyFormatter.format(listTotal, currencyCode: currencyCode))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                HStack {
                    Text("Selected total")
                    Spacer()
                    Text(CurrencyFormatter.format(selectionTotal, currencyCode: currencyCode))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func parsedRow(_ item: ShoppingListItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            checkboxButton(for: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(2)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                if let caption = priceCaption(for: item) {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough(item.isChecked, color: .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture {
                revertToText(item)
            }

            Stepper(value: Binding(
                get: { item.quantity },
                set: { item.quantity = max(1, $0); save() }
            ), in: 1...999) {
                EmptyView()
            }
            .labelsHidden()
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func textRow(_ item: ShoppingListItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            checkboxButton(for: item)

            TextField("Start typing…", text: Binding(
                get: { item.rawText.isEmpty ? item.name : item.rawText },
                set: { item.rawText = $0; save() }
            ), axis: .vertical)
            .font(.body)
            .lineLimit(1...3)
            .focused($focusedField, equals: .item(item.id))
            .textInputAutocapitalization(.sentences)
            .onChange(of: item.rawText) { _, newValue in
                handleTextItemChange(item, newValue: newValue)
            }
            .onAppear {
                applyFocusRequest(for: .item(item.id))
            }
        }
        .padding(.vertical, 6)
    }

    private func checkboxButton(for item: ShoppingListItem) -> some View {
        Button {
            item.isChecked.toggle()
            save()
        } label: {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isChecked ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isChecked ? "Checked" : "Unchecked")
    }

    private func applyFocusRequest(for field: FocusField) {
        guard focusRequest == field else { return }
        focusedField = field
        focusRequest = nil
    }

    private func requestFocus(_ field: FocusField) {
        focusRequest = field
        DispatchQueue.main.async {
            focusedField = field
            if focusedField == field {
                focusRequest = nil
            }
        }
    }

    private func priceCaption(for item: ShoppingListItem) -> String? {
        guard let price = item.price else { return nil }

        let unit = CurrencyFormatter.format(price, currencyCode: currencyCode)
        if item.quantity == 1 {
            return unit
        }
        guard let lineTotal = item.lineTotal else { return unit }

        let total = CurrencyFormatter.format(lineTotal, currencyCode: currencyCode)
        return "\(unit) × \(item.quantity) · \(total)"
    }

    private func commitFocusChange(from previous: FocusField?) {
        guard let previous else { return }
        switch previous {
        case .draft:
            commitDraft()
        case .item(let id):
            commitTextItem(id: id)
        }
    }

    private func commitDraft() {
        let lines = draftText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return }

        for line in lines {
            addParsedLine(line)
        }
        draftText = ""
    }

    private func commitTextItem(id: UUID) {
        guard let item = items.first(where: { $0.id == id }), !item.isParsed else { return }

        let text = (item.rawText.isEmpty ? item.name : item.rawText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            try? dependencies.shoppingList.delete(item)
            save()
            return
        }

        if text.contains("\n") {
            handleTextItemChange(item, newValue: text)
        } else {
            ShoppingListParser.apply(ShoppingListParser.parse(text), to: item)
            save()
        }
    }

    private func handleDraftChange(_ newValue: String) {
        guard newValue.contains("\n") else { return }

        var parts = newValue.components(separatedBy: "\n")
        let line = parts.removeFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty {
            addParsedLine(line)
        }

        draftText = parts.joined(separator: "\n")
    }

    private func handleTextItemChange(_ item: ShoppingListItem, newValue: String) {
        guard newValue.contains("\n") else { return }

        var parts = newValue.components(separatedBy: "\n")
        let currentLine = parts.removeFirst().trimmingCharacters(in: .whitespacesAndNewlines)

        if currentLine.isEmpty {
            try? dependencies.shoppingList.delete(item)
        } else {
            ShoppingListParser.apply(ShoppingListParser.parse(currentLine), to: item)
        }

        if !parts.isEmpty {
            let remainder = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty {
                draftText = draftText.isEmpty ? remainder : "\(draftText)\n\(remainder)"
            }
        }

        save()
    }

    private func addParsedLine(_ line: String) {
        let parsed = ShoppingListParser.parse(line)
        let item = ShoppingListItem(sortOrder: nextSortOrder())
        ShoppingListParser.apply(parsed, to: item)
        try? dependencies.shoppingList.insert(item)
        save()
    }

    private func revertToText(_ item: ShoppingListItem) {
        commitFocusChange(from: focusedField)

        item.isParsed = false
        item.rawText = ShoppingListParser.rawText(name: item.name, price: item.price, quantity: item.quantity)
        save()

        requestFocus(.item(item.id))
    }

    private func nextSortOrder() -> Int {
        (items.map(\.sortOrder).max() ?? -1) + 1
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            try? dependencies.shoppingList.delete(items[index])
        }
        save()
    }

    private func clearList() {
        for item in items {
            try? dependencies.shoppingList.delete(item)
        }
        draftText = ""
        save()
    }

    private func save() {
        try? dependencies.shoppingList.save()
    }
}
