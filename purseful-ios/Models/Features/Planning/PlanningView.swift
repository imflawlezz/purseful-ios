import SwiftData
import SwiftUI

struct PlanningView: View {
    @Environment(AppState.self) private var appState
    @Bindable private var settings = AppSettings.shared
    @State private var section = 0
    @State private var showAddPayment = false
    @State private var showAddDebt = false
    @State private var showAddGoal = false
    @State private var showPaymentCalendar = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    Text("Payments").tag(0)
                    Text("Debts").tag(1)
                    Text("Goals").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch section {
                case 0:
                    PlannedPaymentsView()
                case 1:
                    DebtsView()
                default:
                    GoalsView()
                }
            }
            .navigationTitle("Planned")
            .onAppear {
                section = appState.planningSection
            }
            .onChange(of: appState.planningSection) { _, newValue in
                section = newValue
            }
            .toolbar {
                if section == 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPaymentCalendar = true } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Calendar")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ToolbarIcon.add { showAddPayment = true }
                    }
                } else if section == 1 {
                    ToolbarItem(placement: .confirmationAction) {
                        ToolbarIcon.add { showAddDebt = true }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        ToolbarIcon.add { showAddGoal = true }
                    }
                }
            }
            .sheet(isPresented: $showAddPayment) {
                PlannedPaymentFormView()
            }
            .sheet(isPresented: $showAddDebt) {
                DebtFormView()
            }
            .sheet(isPresented: $showAddGoal) {
                GoalFormView()
            }
            .sheet(isPresented: $showPaymentCalendar) {
                PaymentCalendarSheet()
            }
        }
        .tint(settings.accentColor)
    }
}

struct PaymentCalendarSheet: View {
    @Query(sort: \PlannedPayment.nextDueDate) private var payments: [PlannedPayment]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PaymentCalendarView(payments: payments.filter(\.isActive))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        ToolbarIcon.done { dismiss() }
                    }
                }
        }
    }
}

private func plannedPaymentColor(_ payment: PlannedPayment) -> Color {
    switch payment.type {
    case .transfer:
        Color.accentColor
    case .income, .expense:
        Color(hex: payment.category?.colorHex ?? "#8E8E93")
    }
}

private func plannedPaymentSubtitle(_ payment: PlannedPayment) -> String {
    switch payment.type {
    case .transfer:
        let from = payment.account?.name ?? "Account"
        let to = payment.toAccount?.name ?? "Account"
        return "Transfer · \(from) → \(to)"
    case .income, .expense:
        return payment.category?.name ?? payment.type.displayName
    }
}

@MainActor
private func makePlannedTransaction(from payment: PlannedPayment, context: ModelContext, date: Date = Date()) -> Transaction {
    let category = payment.type == .transfer
        ? nil
        : CategoryService.resolvedCategory(payment.category, for: payment.type, context: context)

    return Transaction(
        title: payment.name,
        amount: payment.amount,
        type: payment.type,
        date: date,
        note: payment.note,
        account: payment.account,
        toAccount: payment.type == .transfer ? payment.toAccount : nil,
        category: category
    )
}

struct PlannedPaymentsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Query(sort: \PlannedPayment.nextDueDate) private var payments: [PlannedPayment]
    @State private var selectedPayment: PlannedPayment?

    private var pendingPayments: [PlannedPayment] {
        payments.filter { !PlannedPaymentSchedule.isPaidInCurrentPeriod($0) }
    }

    private var paidThisPeriodPayments: [PlannedPayment] {
        payments.filter { PlannedPaymentSchedule.isPaidInCurrentPeriod($0) }
    }

    var body: some View {
        Group {
            if payments.isEmpty {
                EmptyStateView(title: "No Planned Payments", systemImage: "calendar", message: "Add recurring expenses, income, and transfers.")
            } else {
                List {
                    if !pendingPayments.isEmpty {
                        Section("Pending") {
                            ForEach(pendingPayments) { payment in
                                plannedPaymentRow(payment, completed: false)
                            }
                        }
                    }

                    if !paidThisPeriodPayments.isEmpty {
                        Section("Paid This Period") {
                            ForEach(paidThisPeriodPayments) { payment in
                                plannedPaymentRow(payment, completed: true)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedPayment) { payment in
            PlannedPaymentFormView(payment: payment)
        }
    }

    @ViewBuilder
    private func plannedPaymentRow(_ payment: PlannedPayment, completed: Bool) -> some View {
        Button {
            selectedPayment = payment
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(payment.name)
                        .font(.headline)
                        .foregroundStyle(completed ? .secondary : plannedPaymentColor(payment))
                        .strikethrough(completed, color: .secondary)
                    HStack(spacing: 6) {
                        if completed, let lastPaidDate = payment.lastPaidDate {
                            Text("Paid \(DateFormatters.short.string(from: lastPaidDate))")
                        } else {
                            Text(DateFormatters.short.string(from: payment.nextDueDate))
                        }
                        Text(plannedPaymentSubtitle(payment))
                            .foregroundStyle(.secondary)
                        if !payment.isActive {
                            Text("Inactive")
                                .foregroundStyle(.secondary)
                        } else if !completed && payment.isOverdue {
                            Text("Overdue")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(completed ? Color.secondary : (!completed && payment.isOverdue ? Color.red : Color.secondary))
                }
                Spacer()
                Text(CurrencyFormatter.format(
                    payment.amount,
                    currencyCode: payment.account?.currency ?? AppSettings.shared.baseCurrency
                ))
                .foregroundStyle(completed ? .secondary : plannedPaymentColor(payment))
                .strikethrough(completed, color: .secondary)
            }
        }
        .completeSwipe {
            guard !completed else { return }
            markPaid(payment)
        }
        .editDeleteSwipe(
            onEdit: { selectedPayment = payment },
            onDelete: { delete(payment) }
        )
        .rowContextMenu(preview: {
            PlannedPaymentPreviewView(payment: payment, completed: completed)
        }, actions: plannedPaymentActions(payment, completed: completed))
    }

    private func plannedPaymentActions(_ payment: PlannedPayment, completed: Bool) -> [RowAction] {
        var actions: [RowAction] = []
        if !completed {
            actions.append(RowAction(id: "paid", title: "Mark Paid", systemImage: "checkmark.circle") {
                markPaid(payment)
            })
        }
        actions.append(RowAction(id: "edit", title: "Edit", systemImage: "pencil") {
            selectedPayment = payment
        })
        actions.append(RowAction(id: "delete", title: "Delete", systemImage: "trash", role: .destructive) {
            delete(payment)
        })
        return actions
    }

    private func markPaid(_ payment: PlannedPayment) {
        let tx = makePlannedTransaction(from: payment, context: dependencies.repository.context)
        try? dependencies.plannedPayments.markPaid(payment, transaction: tx)
        Haptics.success()
    }

    private func delete(_ payment: PlannedPayment) {
        try? dependencies.plannedPayments.delete(payment)
        Haptics.light()
    }
}

struct PaymentCalendarView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Debt.dueDate) private var debts: [Debt]

    let payments: [PlannedPayment]

    @State private var displayedMonth = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showDailySpendCategories = false

    private let calendar = Calendar.current

    private var weekdayHeaders: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var paymentsByDay: [Date: [PlannedPayment]] {
        var map: [Date: [PlannedPayment]] = [:]
        for payment in payments {
            for day in PlannedPaymentSchedule.occurrences(for: payment, in: displayedMonth, calendar: calendar) {
                map[day, default: []].append(payment)
            }
        }
        return map
    }

    private var calendarCells: [PaymentCalendarGridItem] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }

        var cells: [PaymentCalendarGridItem] = []
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        for index in 0..<leading {
            cells.append(PaymentCalendarGridItem(id: "pad-\(index)", day: nil))
        }

        var date = interval.start
        while date < interval.end {
            cells.append(PaymentCalendarGridItem(id: "day-\(date.timeIntervalSince1970)", day: date))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return cells
    }

    private var selectedDayPayments: [PlannedPayment] {
        paymentsByDay[selectedDay] ?? []
    }

    private var debtsByDay: [Date: [Debt]] {
        var map: [Date: [Debt]] = [:]
        for debt in debts where debt.remainingAmount > 0 {
            guard let dueDate = debt.dueDate else { continue }
            let day = calendar.startOfDay(for: dueDate)
            map[day, default: []].append(debt)
        }
        return map
    }

    private var selectedDayDebts: [Debt] {
        DebtService.debtsDue(on: selectedDay, debts: debts, calendar: calendar)
    }

    private var projectionBreakdown: NetWorthProjectionBreakdown {
        NetWorthProjectionCalculator.breakdown(
            selectedDay: selectedDay,
            accounts: accounts,
            transactions: transactions,
            plannedPayments: payments,
            debts: debts,
            categories: categories,
            baseCurrency: AppSettings.shared.baseCurrency,
            exchangeRates: appState.resolvedExchangeRates(),
            calendar: calendar
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                calendarGrid
                selectedDayDetail
            }
            .padding()
        }
        .navigationTitle("Payment Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.refreshExchangeRates()
        }
        .sheet(isPresented: $showDailySpendCategories) {
            DailySpendCategoryPickerView()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(DateFormatters.monthYear.string(from: displayedMonth))
                .font(.headline)
            Spacer()
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdayHeaders, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarCells) { cell in
                    if let day = cell.day {
                        dayCell(for: day)
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let dayPayments = paymentsByDay[dayStart] ?? []
        let dayDebts = debtsByDay[dayStart] ?? []
        let isSelected = dayStart == selectedDay
        let isToday = calendar.isDateInToday(day)
        let dayNumber = calendar.component(.day, from: day)
        let markerCount = min(3, dayPayments.count + dayDebts.count)

        return Button {
            selectedDay = dayStart
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(.clear)
                            .frame(width: 38, height: 38)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }

                    Text("\(dayNumber)")
                        .font(.callout.weight(isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? Color.accentColor : .primary)
                        .frame(width: 38, height: 38)
                }

                HStack(spacing: 2) {
                    ForEach(0..<markerCount, id: \.self) { index in
                        Circle()
                            .fill(dayMarkerColor(paymentIndex: index, payments: dayPayments, debts: dayDebts))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    private func dayMarkerColor(paymentIndex: Int, payments: [PlannedPayment], debts: [Debt]) -> Color {
        if paymentIndex < payments.count {
            return plannedPaymentColor(payments[paymentIndex])
        }
        return debts[paymentIndex - payments.count].direction.tintColor
    }

    private var selectedDayDetail: some View {
        let breakdown = projectionBreakdown
        let currencyCode = AppSettings.shared.baseCurrency
        let today = calendar.startOfDay(for: Date())
        let isFutureOrToday = calendar.startOfDay(for: selectedDay) >= today

        return VStack(alignment: .leading, spacing: 12) {
            Text(DateFormatters.dayHeader.string(from: selectedDay))
                .font(.headline)

            VStack(spacing: 8) {
                projectionRow("Current net worth", amount: breakdown.current, currencyCode: currencyCode)

                if isFutureOrToday {
                    if breakdown.plannedImpact != 0 {
                        projectionRow(
                            "Planned payments",
                            amount: -breakdown.plannedImpact,
                            currencyCode: currencyCode,
                            tint: .secondary
                        )
                    }

                    if breakdown.debtImpact != 0 {
                        projectionRow(
                            "Debts due",
                            amount: -breakdown.debtImpact,
                            currencyCode: currencyCode,
                            tint: .secondary
                        )
                    }

                    if breakdown.variableSpend > 0 {
                        projectionRow(
                            "Daily spend trend (\(breakdown.variableDayCount)d)",
                            amount: -breakdown.variableSpend,
                            currencyCode: currencyCode,
                            tint: .secondary
                        )
                    } else if AppSettings.shared.dailySpendCategoryIDs.isEmpty {
                        Button {
                            showDailySpendCategories = true
                        } label: {
                            HStack {
                                Text("Add daily spend categories")
                                    .font(.caption)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    projectionRow(
                        "Expected net worth",
                        amount: breakdown.projected,
                        currencyCode: currencyCode,
                        emphasized: true
                    )

                    if !AppSettings.shared.dailySpendCategoryIDs.isEmpty {
                        Text("\(CurrencyFormatter.format(breakdown.dailyAverage, currencyCode: currencyCode))/day · \(breakdown.categorySummary)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
            }

            if selectedDayPayments.isEmpty && selectedDayDebts.isEmpty {
                Text("No planned payments or debts due on this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedDayPayments) { payment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(plannedPaymentColor(payment))
                                Text(plannedPaymentSubtitle(payment))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(
                                CurrencyFormatter.format(
                                    payment.amount,
                                    currencyCode: payment.account?.currency ?? currencyCode
                                )
                            )
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(plannedPaymentColor(payment))
                        }
                    }

                    ForEach(selectedDayDebts) { debt in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(debt.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(debt.direction.tintColor)
                                Text(debt.direction == .iOwe ? "Repayment due" : "Payment expected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(CurrencyFormatter.format(debt.remainingAmount, currencyCode: debt.currency))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(debt.direction.tintColor)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.clear)
                .glassEffect(in: .rect(cornerRadius: 16))
        }
    }

    private func projectionRow(
        _ title: String,
        amount: Decimal,
        currencyCode: String,
        tint: Color = .primary,
        emphasized: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer()
            Text(CurrencyFormatter.format(amount, currencyCode: currencyCode))
                .font(emphasized ? .title3.bold().monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}

private struct PaymentCalendarGridItem: Identifiable {
    let id: String
    let day: Date?
}

struct PlannedPaymentFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    var payment: PlannedPayment?

    @State private var name = ""
    @State private var note = ""
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var frequency: PaymentFrequency = .monthly
    @State private var nextDueDate = Date()
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var selectedToAccount: Account?
    @State private var autoCategorize = false
    @State private var reminderDays = 1
    @State private var isActive = true

    private var filteredCategories: [Category] {
        let categoryType: CategoryType = type == .income ? .income : .expense
        return Category.userSelectable(categories, type: categoryType)
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              CurrencyFormatter.parse(amountText) != nil,
              let selectedAccount else { return false }

        if type == .transfer {
            guard let selectedToAccount, selectedToAccount.id != selectedAccount.id else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .onChange(of: type) { _, newType in
                    if newType == .transfer {
                        selectedCategory = nil
                    } else {
                        selectedToAccount = nil
                        if let category = selectedCategory,
                           category.type != (newType == .income ? CategoryType.income : .expense) {
                            selectedCategory = nil
                        }
                    }
                }

                TextField("Name", text: $name)
                TextField("Note", text: $note, axis: .vertical)
                LabeledAmountField(
                    label: "Amount",
                    amount: $amountText,
                    currencyCode: selectedAccount?.currency ?? AppSettings.shared.baseCurrency
                )
                Picker("Frequency", selection: $frequency) {
                    ForEach(PaymentFrequency.allCases) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
                Picker("Account", selection: $selectedAccount) {
                    Text("Select account").tag(Optional<Account>.none)
                    ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                        Text(account.selectionLabel).tag(Optional(account))
                    }
                }
                if type == .transfer {
                    Picker("To Account", selection: $selectedToAccount) {
                        Text("Select account").tag(Optional<Account>.none)
                        ForEach(AccountPreferences.visibleAccounts(accounts).filter { $0.id != selectedAccount?.id }) { account in
                            Text(account.selectionLabel).tag(Optional(account))
                        }
                    }
                }
                if type != .transfer {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(Optional<Category>.none)
                        ForEach(filteredCategories) { category in
                            CategoryNameLabel.picker(category: category).tag(Optional(category))
                        }
                    }
                }
                Toggle("Active", isOn: $isActive)
                Toggle("Auto-create on due date", isOn: $autoCategorize)
                Stepper("Remind \(reminderDays) day(s) before", value: $reminderDays, in: 1...14)
            }
            .dismissKeyboardOnTap()
            .navigationTitle(payment == nil ? "New Payment" : "Edit Payment")
            .toolbar {
                if let payment, !PlannedPaymentSchedule.isPaidInCurrentPeriod(payment) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            markPaid(payment)
                        } label: {
                            Image(systemName: "checkmark.circle")
                        }
                        .accessibilityLabel("Mark Paid")
                    }
                }
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    showDelete: payment != nil,
                    onDelete: payment == nil ? nil : { deletePayment() },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
            .onAppear {
                loadPayment()
                if payment == nil, selectedAccount == nil {
                    selectedAccount = AccountPreferences.preferredAccount(from: accounts)
                }
            }
        }
    }

    private func loadPayment() {
        guard let payment else { return }
        name = payment.name
        note = payment.note
        amountText = "\(payment.amount)"
        type = payment.type
        frequency = payment.frequency
        nextDueDate = payment.nextDueDate
        selectedCategory = payment.category
        selectedAccount = payment.account
        selectedToAccount = payment.toAccount
        autoCategorize = payment.autoCategorize
        reminderDays = payment.reminderDaysBefore
        isActive = payment.isActive
    }

    private func save() {
        guard let amount = CurrencyFormatter.parse(amountText),
              let account = selectedAccount else { return }

        let target = payment ?? PlannedPayment(name: name, amount: amount)

        target.name = name
        target.note = note
        target.amount = amount
        target.type = type
        target.frequency = frequency
        target.nextDueDate = nextDueDate
        target.account = account
        target.toAccount = type == .transfer ? selectedToAccount : nil
        if type == .transfer {
            target.category = nil
        } else {
            let categoryType: CategoryType = type == .income ? .income : .expense
            target.category = CategoryService.resolvedCategory(
                selectedCategory,
                for: categoryType,
                context: dependencies.repository.context
            )
        }
        target.autoCategorize = autoCategorize
        target.reminderDaysBefore = reminderDays
        target.isActive = isActive

        try? dependencies.plannedPayments.save(
            target,
            isNew: payment == nil,
            createRecurringRuleIfNeeded: autoCategorize
        )
        dismiss()
    }

    private func deletePayment() {
        guard let payment else { return }
        try? dependencies.plannedPayments.delete(payment)
        Haptics.light()
        dismiss()
    }

    private func markPaid(_ payment: PlannedPayment) {
        let tx = makePlannedTransaction(from: payment, context: dependencies.repository.context)
        try? dependencies.plannedPayments.markPaid(payment, transaction: tx)
        Haptics.success()
        dismiss()
    }
}

struct DebtsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Query(sort: \Debt.createdAt, order: .reverse) private var debts: [Debt]
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]
    @State private var selectedDebt: Debt?
    @State private var detailDebt: Debt?

    var body: some View {
        Group {
            if debts.isEmpty {
                EmptyStateView(title: "No Debts", systemImage: "person.2", message: "Track money you owe or are owed.")
            } else {
                List {
                    ForEach(debts) { debt in
                        Button {
                            detailDebt = debt
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(debt.name)
                                        .foregroundStyle(debt.remainingAmount == 0 ? .secondary : debt.direction.tintColor)
                                        .strikethrough(debt.remainingAmount == 0, color: .secondary)
                                    Text(debt.counterparty)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(CurrencyFormatter.format(debt.remainingAmount, currencyCode: debt.currency))
                                    .foregroundStyle(debt.remainingAmount == 0 ? .secondary : debt.direction.tintColor)
                                    .strikethrough(debt.remainingAmount == 0, color: .secondary)
                            }
                        }
                        .completeSwipe {
                            guard debt.remainingAmount > 0 else { return }
                            markDebtPaid(debt)
                        }
                        .editDeleteSwipe(
                            onEdit: { selectedDebt = debt },
                            onDelete: { delete(debt) }
                        )
                        .rowContextMenu(preview: {
                            DebtDetailPreviewView(debt: debt)
                        }, actions: debtRowActions(debt))
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedDebt) { debt in
            DebtFormView(debt: debt)
        }
        .sheet(item: $detailDebt) { debt in
            NavigationStack {
                DebtDetailView(debt: debt)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ToolbarIcon.edit {
                                detailDebt = nil
                                selectedDebt = debt
                            }
                        }
                    }
            }
        }
    }

    private func delete(_ debt: Debt) {
        try? dependencies.debts.delete(debt)
        Haptics.light()
    }

    private func debtRowActions(_ debt: Debt) -> [RowAction] {
        var actions: [RowAction] = []
        if debt.remainingAmount > 0 {
            actions.append(RowAction(id: "paid", title: "Mark Paid", systemImage: "checkmark.circle") {
                markDebtPaid(debt)
            })
        }
        actions.append(RowAction(id: "edit", title: "Edit", systemImage: "pencil") {
            selectedDebt = debt
        })
        actions.append(RowAction(id: "delete", title: "Delete", systemImage: "trash", role: .destructive) {
            delete(debt)
        })
        return actions
    }

    private func markDebtPaid(_ debt: Debt) {
        guard let account = AccountPreferences.preferredAccount(
            from: accounts,
            matchingCurrency: debt.currency
        ) else { return }
        try? dependencies.debts.recordRepayment(
            debt: debt,
            amount: debt.remainingAmount,
            account: account,
            date: Date()
        )
        Haptics.success()
    }
}

struct DebtFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]

    var debt: Debt?

    @State private var name = ""
    @State private var counterparty = ""
    @State private var direction: DebtDirection = .iOwe
    @State private var amountText = ""
    @State private var currency = AppSettings.shared.baseCurrency
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var openingDate = Date()
    @State private var createsLinkedTransactions = true
    @State private var note = ""
    @State private var selectedAccount: Account?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CurrencyFormatter.parse(amountText) != nil
            && (debt != nil || !createsLinkedTransactions || selectedAccount != nil)
    }

    private var openingDateLabel: String {
        direction == .iOwe ? "Borrowed On" : "Lent On"
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Counterparty", text: $counterparty)
                Picker("Direction", selection: $direction) {
                    ForEach(DebtDirection.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                DatePicker(openingDateLabel, selection: $openingDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Currency", selection: $currency) {
                    ForEach(CommonCurrencies.codes, id: \.self) { Text($0).tag($0) }
                }
                LabeledAmountField(label: "Original Amount", amount: $amountText, currencyCode: currency)
                if debt != nil {
                    LabeledContent(
                        "Remaining Balance",
                        value: CurrencyFormatter.format(debt?.remainingAmount ?? 0, currencyCode: currency)
                    )
                } else if createsLinkedTransactions {
                    Picker("Account", selection: $selectedAccount) {
                        Text("Select").tag(Optional<Account>.none)
                        ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                            Text(account.selectionLabel).tag(Optional(account))
                        }
                    }
                }
                Toggle("Create linked transaction", isOn: $createsLinkedTransactions)
                Toggle("Due Date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
                TextField("Note", text: $note)
            }
            .dismissKeyboardOnTap()
            .navigationTitle(debt == nil ? "New Debt" : "Edit Debt")
            .toolbar {
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    showDelete: debt != nil,
                    onDelete: debt == nil ? nil : { deleteDebt() },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
            .onAppear {
                loadDebt()
                if debt == nil, selectedAccount == nil {
                    selectedAccount = AccountPreferences.preferredAccount(
                        from: accounts,
                        matchingCurrency: currency
                    )
                }
            }
        }
    }

    private func loadDebt() {
        guard let debt else { return }
        name = debt.name
        counterparty = debt.counterparty
        direction = debt.direction
        amountText = "\(debt.originalAmount)"
        currency = debt.currency
        hasDueDate = debt.dueDate != nil
        dueDate = debt.dueDate ?? Date()
        openingDate = DebtService.openingTransaction(for: debt)?.date ?? debt.createdAt
        createsLinkedTransactions = debt.createsLinkedTransactions
        note = debt.note
        DebtService.recalculateRemaining(for: debt)
    }

    private func save() {
        guard let amount = CurrencyFormatter.parse(amountText) else { return }

        if let debt {
            debt.name = name
            debt.counterparty = counterparty
            debt.direction = direction
            debt.originalAmount = amount
            debt.currency = currency
            debt.dueDate = hasDueDate ? dueDate : nil
            debt.note = note
            debt.createdAt = openingDate
            debt.createsLinkedTransactions = createsLinkedTransactions
            if debt.createsLinkedTransactions {
                DebtService.syncOpeningTransaction(for: debt, context: dependencies.repository.context)
            }
            try? dependencies.debts.saveExisting(debt)
            dismiss()
            return
        }

        guard !createsLinkedTransactions || selectedAccount != nil else { return }

        let target = Debt(
            name: name,
            counterparty: counterparty,
            direction: direction,
            originalAmount: amount,
            currency: currency,
            dueDate: hasDueDate ? dueDate : nil,
            note: note,
            createdAt: openingDate,
            createsLinkedTransactions: createsLinkedTransactions
        )
        try? dependencies.debts.create(target, account: selectedAccount, openingDate: openingDate)
        dismiss()
    }

    private func deleteDebt() {
        guard let debt else { return }
        try? dependencies.debts.delete(debt)
        Haptics.light()
        dismiss()
    }
}

struct DebtDetailView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var debt: Debt
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]
    @State private var repaymentText = ""
    @State private var repaymentDate = Date()
    @State private var selectedAccount: Account?

    private var isSettled: Bool {
        debt.remainingAmount <= 0
    }

    private var sortedLinkedTransactions: [Transaction] {
        (debt.linkedTransactions ?? []).sorted { $0.date > $1.date }
    }

    private var canApplyRepayment: Bool {
        CurrencyFormatter.parse(repaymentText) != nil
            && (debt.createsLinkedTransactions ? selectedAccount != nil : true)
    }

    private var openingDateLabel: String {
        debt.direction == .iOwe ? "Borrowed On" : "Lent On"
    }

    private var openingDate: Date {
        DebtService.openingTransaction(for: debt)?.date ?? debt.createdAt
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Counterparty", value: debt.counterparty.isEmpty ? "—" : debt.counterparty)
                LabeledContent("Remaining", value: CurrencyFormatter.format(debt.remainingAmount, currencyCode: debt.currency))
                LabeledContent("Original", value: CurrencyFormatter.format(debt.originalAmount, currencyCode: debt.currency))
                LabeledContent("Direction", value: debt.direction.displayName)
                LabeledContent(openingDateLabel, value: DateFormatters.short.string(from: openingDate))
                if let dueDate = debt.dueDate {
                    LabeledContent("Due Date", value: DateFormatters.short.string(from: dueDate))
                }
                if !debt.note.isEmpty {
                    LabeledContent("Note", value: debt.note)
                }
                LabeledContent("Linked transactions", value: debt.createsLinkedTransactions ? "On" : "Off")
            }

            Section("Record Repayment") {
                if isSettled {
                    Label("Fully repaid", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if debt.createsLinkedTransactions {
                        Picker("Account", selection: $selectedAccount) {
                            Text("Select").tag(Optional<Account>.none)
                            ForEach(AccountPreferences.visibleAccounts(accounts)) { account in
                                Text(account.selectionLabel).tag(Optional(account))
                            }
                        }
                    }
                    DatePicker("Repayment Date", selection: $repaymentDate, displayedComponents: [.date, .hourAndMinute])
                    LabeledAmountField(label: "Repayment Amount", amount: $repaymentText, currencyCode: debt.currency)
                    FormActionButton(
                        title: "Apply Repayment",
                        systemImage: "checkmark.circle",
                        disabled: !canApplyRepayment
                    ) {
                        applyRepayment()
                    }
                }
            }

            Section("Linked Transactions") {
                if debt.createsLinkedTransactions {
                    if !sortedLinkedTransactions.isEmpty {
                        ForEach(sortedLinkedTransactions) { transaction in
                            TransactionRowView(transaction: transaction, baseCurrency: debt.currency)
                        }
                    } else {
                        Text("No linked transactions")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("This debt tracks balance without creating transactions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(debt.name)
        .onAppear {
            DebtService.recalculateRemaining(for: debt)
            if selectedAccount == nil {
                selectedAccount = AccountPreferences.preferredAccount(
                    from: accounts,
                    matchingCurrency: debt.currency
                )
            }
        }
        .toolbar {
            if debt.remainingAmount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        markDebtPaid()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel("Mark Paid")
                }
            }
            DeleteLeadingToolbar {
                try? dependencies.debts.delete(debt)
                dismiss()
            }
        }
    }

    private func markDebtPaid() {
        guard debt.remainingAmount > 0,
              let account = AccountPreferences.preferredAccount(
                from: accounts,
                matchingCurrency: debt.currency
              ) else { return }

        try? dependencies.debts.recordRepayment(
            debt: debt,
            amount: debt.remainingAmount,
            account: account,
            date: Date()
        )
        Haptics.success()
    }

    private func applyRepayment() {
        guard debt.remainingAmount > 0,
              let amount = CurrencyFormatter.parse(repaymentText) else { return }
        if debt.createsLinkedTransactions, selectedAccount == nil { return }

        try? dependencies.debts.recordRepayment(
            debt: debt,
            amount: amount,
            account: selectedAccount,
            date: repaymentDate
        )
        repaymentText = ""
        Haptics.success()
    }
}

struct GoalsView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @State private var selectedGoal: Goal?
    @State private var detailGoal: Goal?

    var body: some View {
        Group {
            if goals.isEmpty {
                EmptyStateView(title: "No Goals", systemImage: "star", message: "Set savings goals to stay motivated.")
            } else {
                List {
                    ForEach(goals) { goal in
                        Button {
                            detailGoal = goal
                        } label: {
                            GoalRowView(goal: goal)
                        }
                        .completeSwipe {
                            guard !goal.isCompleted else { return }
                            markGoalComplete(goal)
                        }
                        .editDeleteSwipe(
                            onEdit: { selectedGoal = goal },
                            onDelete: { delete(goal) }
                        )
                        .rowContextMenu(preview: {
                            GoalDetailPreviewView(goal: goal)
                        }, actions: goalRowActions(goal))
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedGoal) { goal in
            GoalFormView(goal: goal)
        }
        .sheet(item: $detailGoal) { goal in
            NavigationStack {
                GoalDetailView(goal: goal)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ToolbarIcon.edit {
                                detailGoal = nil
                                selectedGoal = goal
                            }
                        }
                    }
            }
        }
    }

    private func delete(_ goal: Goal) {
        try? dependencies.goals.delete(goal)
        Haptics.light()
    }

    private func goalRowActions(_ goal: Goal) -> [RowAction] {
        var actions: [RowAction] = []
        if !goal.isCompleted {
            actions.append(RowAction(id: "complete", title: "Mark Complete", systemImage: "checkmark.circle") {
                markGoalComplete(goal)
            })
        }
        actions.append(RowAction(id: "edit", title: "Edit", systemImage: "pencil") {
            selectedGoal = goal
        })
        actions.append(RowAction(id: "delete", title: "Delete", systemImage: "trash", role: .destructive) {
            delete(goal)
        })
        return actions
    }

    private func markGoalComplete(_ goal: Goal) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            goal.currentAmount = goal.targetAmount
            goal.isCompleted = true
        }
        try? dependencies.goals.markComplete(goal)
        Haptics.success()
    }
}

struct GoalRowView: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            GoalProgressIndicator(
                progress: goal.progress,
                colorHex: goal.colorHex,
                isCompleted: goal.isCompleted,
                lineWidth: 6,
                size: 44
            )
            VStack(alignment: .leading) {
                Text(goal.name)
                    .foregroundStyle(Color(hex: goal.colorHex))
                Text("\(Int(goal.progress * 100))% of \(CurrencyFormatter.format(goal.targetAmount, currencyCode: AppSettings.shared.baseCurrency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GoalFormView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isHidden }, sort: \Account.sortOrder) private var accounts: [Account]

    var goal: Goal?

    @State private var name = ""
    @State private var targetText = ""
    @State private var currentText = ""
    @State private var icon = "star.fill"
    @State private var colorHex = "#34C759"
    @State private var targetDate = Date()
    @State private var hasTargetDate = false
    @State private var note = ""
    @State private var linkedAccount: Account?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CurrencyFormatter.parse(targetText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                LabeledAmountField(
                    label: "Target Amount",
                    amount: $targetText,
                    currencyCode: AppSettings.shared.baseCurrency
                )
                if goal != nil {
                    LabeledAmountField(
                        label: "Current Saved",
                        amount: $currentText,
                        currencyCode: AppSettings.shared.baseCurrency
                    )
                }
                TextField("Note", text: $note, axis: .vertical)
                Picker("Credit to Account", selection: $linkedAccount) {
                    Text("None").tag(Optional<Account>.none)
                    ForEach(accounts) { account in
                        Text(account.selectionLabel).tag(Optional(account))
                    }
                }
                SymbolPickerGrid(selectedSymbol: $icon)
                ColorPickerGrid(selectedHex: $colorHex)
                Toggle("Target Date", isOn: $hasTargetDate)
                if hasTargetDate {
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .toolbar {
                FormLeadingToolbar(
                    onCancel: { dismiss() },
                    showDelete: goal != nil,
                    onDelete: goal == nil ? nil : { deleteGoal() },
                    onSave: { save() },
                    saveDisabled: !canSave
                )
            }
            .onAppear(perform: loadGoal)
        }
    }

    private func loadGoal() {
        guard let goal else { return }
        name = goal.name
        targetText = "\(goal.targetAmount)"
        currentText = "\(goal.currentAmount)"
        icon = goal.icon
        colorHex = goal.colorHex
        hasTargetDate = goal.targetDate != nil
        targetDate = goal.targetDate ?? Date()
        note = goal.note
        linkedAccount = goal.linkedAccount
    }

    private func save() {
        guard let target = CurrencyFormatter.parse(targetText) else { return }

        let item = goal ?? Goal(name: name, targetAmount: target)
        let wasCompleted = goal?.isCompleted ?? false

        item.name = name
        item.targetAmount = target
        item.icon = icon
        item.colorHex = colorHex
        item.targetDate = hasTargetDate ? targetDate : nil
        item.note = note
        item.linkedAccount = linkedAccount

        if goal != nil, let current = CurrencyFormatter.parse(currentText) {
            item.currentAmount = current
            item.isCompleted = current >= target
        }

        try? dependencies.goals.save(item, isNew: goal == nil, wasCompleted: wasCompleted)
        dismiss()
    }

    private func deleteGoal() {
        guard let goal else { return }
        try? dependencies.goals.delete(goal)
        Haptics.light()
        dismiss()
    }
}

struct GoalDetailView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal
    @State private var contributionText = ""

    private var estimatedCompletion: String? {
        guard !goal.isCompleted, goal.currentAmount > 0, goal.targetAmount > goal.currentAmount else { return nil }
        let remaining = goal.targetAmount - goal.currentAmount
        let daysSinceCreation = max(1, Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 1)
        let dailyRate = goal.currentAmount / Decimal(daysSinceCreation)
        guard dailyRate > 0 else { return nil }
        let daysLeft = NSDecimalNumber(decimal: remaining / dailyRate).intValue
        guard let date = Calendar.current.date(byAdding: .day, value: daysLeft, to: Date()) else { return nil }
        return DateFormatters.short.string(from: date)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    GoalProgressIndicator(
                        progress: goal.progress,
                        colorHex: goal.colorHex,
                        isCompleted: goal.isCompleted,
                        lineWidth: 10,
                        size: 120
                    )
                    Spacer()
                }
                LabeledContent("Current", value: CurrencyFormatter.format(goal.currentAmount, currencyCode: AppSettings.shared.baseCurrency))
                LabeledContent("Target", value: CurrencyFormatter.format(goal.targetAmount, currencyCode: AppSettings.shared.baseCurrency))
                if let targetDate = goal.targetDate {
                    LabeledContent("Target Date", value: DateFormatters.short.string(from: targetDate))
                }
                if !goal.note.isEmpty {
                    LabeledContent("Note", value: goal.note)
                }
                if let estimatedCompletion {
                    LabeledContent("Estimated completion", value: estimatedCompletion)
                }
            }

            Section("Add Contribution") {
                if goal.isCompleted {
                    Label("Goal completed", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LabeledAmountField(
                        label: "Contribution",
                        amount: $contributionText,
                        currencyCode: AppSettings.shared.baseCurrency
                    )
                    FormActionButton(
                        title: "Apply Contribution",
                        systemImage: "checkmark.circle",
                        disabled: CurrencyFormatter.parse(contributionText) == nil
                    ) {
                        contribute()
                    }
                }
            }
        }
        .navigationTitle(goal.name)
        .toolbar {
            if !goal.isCompleted {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        markComplete()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel("Mark Complete")
                }
            }
            DeleteLeadingToolbar {
                try? dependencies.goals.delete(goal)
                dismiss()
            }
        }
    }

    private func markComplete() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            goal.currentAmount = goal.targetAmount
            goal.isCompleted = true
        }
        try? dependencies.goals.markComplete(goal)
        Haptics.success()
    }

    private func contribute() {
        guard !goal.isCompleted,
              let amount = CurrencyFormatter.parse(contributionText) else { return }

        let wasCompleted = goal.isCompleted
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            try? dependencies.goals.contribute(goal, amount: amount)
        }
        contributionText = ""

        if goal.isCompleted && !wasCompleted {
            Haptics.success()
        }
    }
}
