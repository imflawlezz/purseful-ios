import Foundation
import SwiftUI

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash, debitCard, creditCard, savings, loan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: String(localized: "Cash")
        case .debitCard: String(localized: "Debit Card")
        case .creditCard: String(localized: "Credit Card")
        case .savings: String(localized: "Savings")
        case .loan: String(localized: "Loan")
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
        case .income: String(localized: "Income")
        case .expense: String(localized: "Expense")
        case .transfer: String(localized: "Transfer")
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
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .custom: String(localized: "Custom")
        }
    }
}

enum PaymentFrequency: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, biweekly, monthly, yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: String(localized: "Once")
        case .daily: String(localized: "Daily")
        case .weekly: String(localized: "Weekly")
        case .biweekly: String(localized: "Biweekly")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }
}

enum DebtDirection: String, Codable, CaseIterable, Identifiable {
    case iOwe, theyOwe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iOwe: String(localized: "I Owe")
        case .theyOwe: String(localized: "They Owe Me")
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
        case .sevenDays: String(localized: "7D")
        case .thirtyDays: String(localized: "30D")
        case .threeMonths: String(localized: "3M")
        case .sixMonths: String(localized: "6M")
        case .twelveMonths: String(localized: "12M")
        case .custom: String(localized: "Custom")
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

    /// Inclusive start-of-day … end-of-day.
    static func normalizedCustomRange(start: Date, end: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let orderedStart = calendar.startOfDay(for: min(start, end))
        let endDay = calendar.startOfDay(for: max(start, end))
        let orderedEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDay) ?? endDay
        return (orderedStart, orderedEnd)
    }
}

/// Chart buckets scale with the selected period.
enum ReportChartGranularity {
    case day, week, month

    static func preferred(from start: Date, to end: Date, calendar: Calendar = .current) -> Self {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let days = max(
            1,
            (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        )
        switch days {
        case ...14: return .day
        case ...100: return .week
        default: return .month
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }

    func alignedStart(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }

    func bucketEnd(after start: Date, calendar: Calendar) -> Date {
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(604_800)
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(2_592_000)
        }
    }

    func bucketStarts(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        var cursor = alignedStart(for: start, calendar: calendar)
        let limit = end
        var starts: [Date] = []
        while cursor <= limit {
            starts.append(cursor)
            let next = bucketEnd(after: cursor, calendar: calendar)
            if next <= cursor { break }
            cursor = next
        }
        return starts
    }

    /// Cap line charts at ~12 points.
    func sampleDates(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let daySpan = max(
            1,
            (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
        )
        let step = max(1, Int(ceil(Double(daySpan) / 12.0)))
        var dates: [Date] = []
        var cursor = startDay
        while cursor <= endDay {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor), next > cursor else { break }
            cursor = next
        }
        if dates.last != endDay {
            dates.append(endDay)
        }
        return dates
    }

    func axisLabel(for date: Date) -> String {
        switch self {
        case .day:
            date.formatted(.dateTime.day().month(.abbreviated))
        case .week:
            date.formatted(.dateTime.day().month(.abbreviated))
        case .month:
            date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }
}

enum TransactionSortOption: String, CaseIterable, Identifiable {
    case dateDescending, dateAscending, amountDescending, amountAscending, category

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateDescending: String(localized: "Date (Newest)")
        case .dateAscending: String(localized: "Date (Oldest)")
        case .amountDescending: String(localized: "Amount (High)")
        case .amountAscending: String(localized: "Amount (Low)")
        case .category: String(localized: "Category")
        }
    }
}
