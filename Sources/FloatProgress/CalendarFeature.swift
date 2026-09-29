import Foundation

struct CalendarDay: Identifiable, Equatable {
    let date: Date
    let day: Int
    let isInDisplayedMonth: Bool
    let lunarText: String
    let festival: String?
    let solarTerm: String?
    let workdayKind: ChinaWorkdayKind

    var id: Date { date }

}

struct CalendarMonth: Equatable {
    static let supportedYears = 1900...2100

    let monthStart: Date
    let days: [CalendarDay]
    let workdayCount: Int
    let restDayCount: Int

    static func make(
        containing date: Date,
        firstWeekday: Int = 2,
        calendar inputCalendar: Calendar = .current
    ) -> CalendarMonth {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = firstWeekday == 1 ? 1 : 2

        let components = calendar.dateComponents([.year, .month], from: date)
        let monthStart = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart

        var days: [CalendarDay] = []
        days.reserveCapacity(42)
        var workdayCount = 0
        var restDayCount = 0

        for offset in 0..<42 {
            guard let gridDate = calendar.date(byAdding: .day, value: offset, to: gridStart) else { continue }
            let isInDisplayedMonth = calendar.isDate(gridDate, equalTo: monthStart, toGranularity: .month)
            let kind = ChinaWorkdayCalendar.kind(for: gridDate, calendar: calendar)
            if isInDisplayedMonth {
                if kind.isWorkday { workdayCount += 1 } else { restDayCount += 1 }
            }
            let lunar = ChineseCalendarText.lunarText(for: gridDate, calendar: calendar)
            days.append(
                CalendarDay(
                    date: gridDate,
                    day: calendar.component(.day, from: gridDate),
                    isInDisplayedMonth: isInDisplayedMonth,
                    lunarText: lunar.short,
                    festival: ChineseCalendarText.festival(
                        for: gridDate,
                        lunarMonth: lunar.month,
                        lunarDay: lunar.day,
                        calendar: calendar
                    ),
                    solarTerm: SolarTerms.name(for: gridDate, calendar: calendar),
                    workdayKind: kind
                )
            )
        }

        return CalendarMonth(
            monthStart: monthStart,
            days: days,
            workdayCount: workdayCount,
            restDayCount: restDayCount
        )
    }

    static func monthStart(
        year: Int,
        month: Int,
        calendar inputCalendar: Calendar = .current
    ) -> Date? {
        guard supportedYears.contains(year), (1...12).contains(month) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    static func selectionDate(
        forDisplayedMonth monthStart: Date,
        today: Date,
        calendar inputCalendar: Calendar = .current
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        if calendar.isDate(monthStart, equalTo: today, toGranularity: .month) {
            return calendar.startOfDay(for: today)
        }
        let components = calendar.dateComponents([.year, .month], from: monthStart)
        return calendar.date(from: components) ?? calendar.startOfDay(for: monthStart)
    }

    static func nextOfficialRestDay(
        after date: Date,
        calendar inputCalendar: Calendar = .current
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        let today = calendar.startOfDay(for: date)
        for offset in 0...370 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if ChinaWorkdayCalendar.kind(for: candidate, calendar: calendar) == .publicHoliday {
                return candidate
            }
        }
        return nil
    }
}

enum ChineseCalendarText {
    private static let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private static let zodiacAnimals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    private static let lunarMonths = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]
    private static let lunarDays = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]
    private static let gregorianFestivals: [Int: String] = [
        101: "元旦", 214: "情人节", 308: "妇女节", 312: "植树节",
        501: "劳动节", 504: "青年节", 601: "儿童节", 701: "建党节",
        801: "建军节", 910: "教师节", 1001: "国庆节"
    ]
    private static let lunarFestivals: [Int: String] = [
        101: "春节", 115: "元宵", 202: "龙抬头", 505: "端午",
        707: "七夕", 715: "中元", 815: "中秋", 909: "重阳", 1208: "腊八"
    ]

    static func lunarText(
        for date: Date,
        calendar: Calendar = .current
    ) -> (short: String, month: Int, day: Int) {
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = calendar.timeZone
        let components = chinese.dateComponents([.month, .day, .isLeapMonth], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        guard lunarMonths.indices.contains(month - 1), lunarDays.indices.contains(day - 1) else {
            return ("", month, day)
        }
        if day == 1 {
            return ((components.isLeapMonth == true ? "闰" : "") + lunarMonths[month - 1], month, day)
        }
        return (lunarDays[day - 1], month, day)
    }

    static func fullText(for date: Date, calendar: Calendar = .current) -> String {
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = calendar.timeZone
        let components = chinese.dateComponents([.year, .month, .day, .isLeapMonth], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              year > 0,
              lunarMonths.indices.contains(month - 1),
              lunarDays.indices.contains(day - 1) else {
            return ""
        }

        let cycleIndex = year - 1
        let stem = heavenlyStems[cycleIndex % heavenlyStems.count]
        let branch = earthlyBranches[cycleIndex % earthlyBranches.count]
        let zodiac = zodiacAnimals[cycleIndex % zodiacAnimals.count]
        let leapPrefix = components.isLeapMonth == true ? "闰" : ""
        return "\(stem)\(branch)年（\(zodiac)）\(leapPrefix)\(lunarMonths[month - 1])\(lunarDays[day - 1])"
    }

    static func festival(
        for date: Date,
        lunarMonth: Int,
        lunarDay: Int,
        calendar inputCalendar: Calendar = .current
    ) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        let values = calendar.dateComponents([.month, .day, .weekday, .weekdayOrdinal], from: date)
        if let month = values.month, let day = values.day,
           let fixed = gregorianFestivals[month * 100 + day] {
            return fixed
        }
        if values.month == 5, values.weekday == 1, values.weekdayOrdinal == 2 { return "母亲节" }
        if values.month == 6, values.weekday == 1, values.weekdayOrdinal == 3 { return "父亲节" }
        if let lunar = lunarFestivals[lunarMonth * 100 + lunarDay] { return lunar }

        if lunarMonth == 12,
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            var chinese = Calendar(identifier: .chinese)
            chinese.timeZone = calendar.timeZone
            let next = chinese.dateComponents([.month, .day], from: tomorrow)
            if next.month == 1, next.day == 1 { return "除夕" }
        }
        return nil
    }
}

enum SolarTerms {
    private static let names = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ]
    private static let minuteOffsets: [Double] = [
        0, 21_208, 42_467, 63_836, 85_337, 107_014,
        128_867, 150_921, 173_149, 195_551, 218_072, 240_693,
        263_343, 285_989, 308_563, 331_033, 353_350, 375_494,
        397_447, 419_210, 440_795, 462_224, 483_532, 504_758
    ]
    private static let tropicalYearMilliseconds = 31_556_925_974.7
    private static let baseDate = Date(timeIntervalSince1970: -2_208_549_300) // 1900-01-06 02:05 UTC

    static func name(for date: Date, calendar inputCalendar: Calendar = .current) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        let year = calendar.component(.year, from: date)
        guard (1900...2100).contains(year) else { return nil }

        for index in names.indices {
            let milliseconds = tropicalYearMilliseconds * Double(year - 1900)
                + minuteOffsets[index] * 60_000
            let termDate = baseDate.addingTimeInterval(milliseconds / 1_000)
            if calendar.isDate(termDate, inSameDayAs: date) { return names[index] }
        }
        return nil
    }
}
