import Foundation
import Testing
@testable import purseful_ios

struct NotificationHelpersTests {
    @Test func budgetAlertDedupKeyIncludesBudgetPeriodAndLevel() {
        let budgetID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let periodStart = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let thresholdKey = NotificationHelpers.budgetAlertDedupKey(
            budgetID: budgetID,
            periodStart: periodStart,
            level: .threshold
        )
        let exceededKey = NotificationHelpers.budgetAlertDedupKey(
            budgetID: budgetID,
            periodStart: periodStart,
            level: .exceeded
        )

        #expect(thresholdKey.contains(budgetID.uuidString))
        #expect(thresholdKey.hasSuffix(".threshold"))
        #expect(exceededKey.hasSuffix(".exceeded"))
        #expect(thresholdKey != exceededKey)
    }

    @Test func nextMondayMorningReturnsFutureMondayAtNine() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 11
        components.hour = 15
        let wednesday = Calendar.current.date(from: components)!

        let nextMonday = NotificationHelpers.nextMondayMorning(from: wednesday)
        #expect(nextMonday != nil)

        let mondayComponents = Calendar.current.dateComponents([.weekday, .hour, .minute], from: nextMonday!)
        #expect(mondayComponents.weekday == 2)
        #expect(mondayComponents.hour == 9)
        #expect(mondayComponents.minute == 0)
        #expect(nextMonday! > wednesday)
    }

    @Test func previousCalendarWeekIsMondayThroughSundayBeforeReference() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
        let week = NotificationHelpers.previousCalendarWeek(from: wednesday, calendar: calendar)
        #expect(week != nil)

        let start = calendar.dateComponents([.year, .month, .day, .weekday], from: week!.start)
        let end = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: week!.end)

        #expect(start.year == 2026)
        #expect(start.month == 6)
        #expect(start.day == 1)
        #expect(start.weekday == 2)

        #expect(end.year == 2026)
        #expect(end.month == 6)
        #expect(end.day == 7)
        #expect(end.weekday == 1)
        #expect(end.hour == 23)
        #expect(end.minute == 59)
        #expect(end.second == 59)
    }
}
