import Foundation
import SwiftUI

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash, debitCard, creditCard, savings, loan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: "Cash"
        case .debitCard: "Debit Card"
        case .creditCard: "Credit Card"
        case .savings: "Savings"
        case .loan: "Loan"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: "banknote"
        case .debitCard: "creditcard"
        case .creditCard: "creditcard.fill"
        case .savings: "building.columns"
        case .loan: "arrow.left.arrow.right"
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income, expense, transfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        }
    }
}

enum CategoryType: String, Codable, CaseIterable {
    case income, expense
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .custom: "Custom"
        }
    }
}

enum PaymentFrequency: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, biweekly, monthly, yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: "Once"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

enum DebtDirection: String, Codable, CaseIterable, Identifiable {
    case iOwe, theyOwe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iOwe: "I Owe"
        case .theyOwe: "They Owe Me"
        }
    }

    var tintColor: Color {
        switch self {
        case .iOwe: Color(hex: "#FF6482")
        case .theyOwe: Color(hex: "#34C759")
        }
    }
}

enum BankConnectionStatus: String, Codable, CaseIterable {
    case active, expired, error
}

enum ReportPeriod: String, CaseIterable, Identifiable {
    case sevenDays, thirtyDays, threeMonths, sixMonths, twelveMonths, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenDays: "7D"
        case .thirtyDays: "30D"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .twelveMonths: "12M"
        case .custom: "Custom"
        }
    }

    var dateRange: (start: Date, end: Date) {
        let end = Date()
        let calendar = Calendar.current
        let start: Date
        switch self {
        case .sevenDays:
            start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case .thirtyDays:
            start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        case .threeMonths:
            start = calendar.date(byAdding: .month, value: -3, to: end) ?? end
        case .sixMonths:
            start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        case .twelveMonths:
            start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        case .custom:
            start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        }
        return (start, end)
    }
}

enum TransactionSortOption: String, CaseIterable, Identifiable {
    case dateDescending, dateAscending, amountDescending, amountAscending, category

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateDescending: "Date (Newest)"
        case .dateAscending: "Date (Oldest)"
        case .amountDescending: "Amount (High)"
        case .amountAscending: "Amount (Low)"
        case .category: "Category"
        }
    }
}
