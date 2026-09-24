import Foundation

enum ChinaWorkdayKind: Equatable {
    case regularWorkday
    case weekend
    case publicHoliday
    case adjustedWorkday
    case unsupportedWeekday(year: Int)
    case unsupportedWeekend(year: Int)

    var isWorkday: Bool {
        switch self {
        case .regularWorkday, .adjustedWorkday, .unsupportedWeekday:
            true
        case .weekend, .publicHoliday, .unsupportedWeekend:
            false
        }
    }

    var title: String {
        switch self {
        case .regularWorkday: "普通工作日"
        case .weekend: "普通周末"
        case .publicHoliday: "节假日休息"
        case .adjustedWorkday: "调休工作日"
        case let .unsupportedWeekday(year): "普通工作日（\(year) 年调休数据未内置）"
        case let .unsupportedWeekend(year): "普通周末（\(year) 年调休数据未内置）"
        }
    }
}

/// A tiny, offline override table built from the annual notices published by
/// the General Office of the State Council. Normal weekdays/weekends are
/// calculated, so the table only needs official holiday spans and makeup days.
enum ChinaWorkdayCalendar {
    static let supportedYears = ChinaWorkdayData.supportedYears
    static let coverageText = ChinaWorkdayData.coverageText

    static func kind(for date: Date, calendar: Calendar = .current) -> ChinaWorkdayKind {
        // Official schedules use Gregorian civil dates. Preserve the caller's
        // time zone while ignoring any alternate user-selected calendar era.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday else {
            return .unsupportedWeekday(year: 0)
        }

        let key = year * 10_000 + month * 100 + day
        if ChinaWorkdayData.adjustedWorkdays.contains(key) { return .adjustedWorkday }
        if ChinaWorkdayData.publicHolidays.contains(key) { return .publicHoliday }

        let isWeekend = weekday == 1 || weekday == 7
        guard supportedYears.contains(year) else {
            return isWeekend ? .unsupportedWeekend(year: year) : .unsupportedWeekday(year: year)
        }
        return isWeekend ? .weekend : .regularWorkday
    }

}
