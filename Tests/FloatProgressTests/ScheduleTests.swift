import AppKit
import Foundation
import Testing
@testable import FloatProgress

struct ScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: hour, minute: minute, second: second))!
    }

    private func chinaDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var chinaCalendar = Calendar(identifier: .gregorian)
        chinaCalendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return chinaCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func currentCalendarDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var currentCalendar = Calendar(identifier: .gregorian)
        currentCalendar.timeZone = Calendar.current.timeZone
        return currentCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var chinaCalendar: Calendar {
        var chinaCalendar = Calendar(identifier: .gregorian)
        chinaCalendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return chinaCalendar
    }

    @Test func calendarPopoverKeepsOneMenuBarTopDistance() {
        let hiddenCountdownFrame = NSRect(x: 571, y: 377, width: 436, height: 576)
        let visibleCountdownFrame = NSRect(x: 507, y: 382, width: 436, height: 576)
        let menuBarBottom: CGFloat = 949

        let hiddenAligned = CalendarPopoverPlacement.aligningTopEdge(
            of: hiddenCountdownFrame,
            toMenuBarBottom: menuBarBottom
        )
        let visibleAligned = CalendarPopoverPlacement.aligningTopEdge(
            of: visibleCountdownFrame,
            toMenuBarBottom: menuBarBottom
        )

        #expect(hiddenAligned.maxY == menuBarBottom - CalendarPopoverPlacement.windowTopGap)
        #expect(visibleAligned.maxY == hiddenAligned.maxY)
        #expect(hiddenAligned.minX == hiddenCountdownFrame.minX)
        #expect(visibleAligned.minX == visibleCountdownFrame.minX)
    }

    @Test func runningDaySchedule() {
        let result = Schedule.snapshot(now: date(13, 30), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(result.phase == .running)
        #expect(result.remaining == 4.5 * 3600)
    }

    @Test func beforeStart() {
        let result = Schedule.snapshot(now: date(8), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(result.phase == .waiting)
        #expect(result.remaining == 3600)
    }

    @Test func overnightSchedule() {
        let result = Schedule.snapshot(now: date(2), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(result.phase == .running)
        #expect(result.remaining == 4 * 3600)
    }

    @Test func schedulePhasesAreExactAtDaytimeBoundaries() {
        let beforeStart = Schedule.snapshot(now: date(8, 59, 59), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(beforeStart.phase == .waiting)
        #expect(beforeStart.remaining == 1)

        let atStart = Schedule.snapshot(now: date(9), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(atStart.phase == .running)
        #expect(atStart.remaining == 9 * 3600)

        let finalSecond = Schedule.snapshot(now: date(17, 59, 59), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(finalSecond.phase == .running)
        #expect(finalSecond.remaining == 1)

        let atEnd = Schedule.snapshot(now: date(18), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(atEnd.phase == .finished)
        #expect(atEnd.remaining == 0)
    }

    @Test func schedulePhasesAreExactAtOvernightBoundaries() {
        let finalSecond = Schedule.snapshot(now: date(5, 59, 59), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(finalSecond.phase == .running)
        #expect(finalSecond.remaining == 1)

        let atEnd = Schedule.snapshot(now: date(6), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(atEnd.phase == .finished)
        #expect(atEnd.remaining == 0)

        let beforeStandby = Schedule.snapshot(now: date(20, 59, 59), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(beforeStandby.phase == .finished)

        let atStandby = Schedule.snapshot(now: date(21), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(atStandby.phase == .waiting)
        #expect(atStandby.remaining == 3600)

        let beforeStart = Schedule.snapshot(now: date(21, 59, 59), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(beforeStart.phase == .waiting)
        #expect(beforeStart.remaining == 1)

        let atStart = Schedule.snapshot(now: date(22), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
        #expect(atStart.phase == .running)
        #expect(atStart.remaining == 8 * 3600)
    }

    @Test func nextScheduleTransitionHandlesDaytimeAndOvernightPlans() {
        #expect(Schedule.nextTransition(after: date(8), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar) == date(9))
        #expect(Schedule.nextTransition(after: date(12), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar) == date(18))
        #expect(
            Schedule.nextTransition(after: date(20), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
                == calendar.date(byAdding: .day, value: 1, to: date(9))
        )

        #expect(Schedule.nextTransition(after: date(2), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar) == date(6))
        #expect(Schedule.nextTransition(after: date(12), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar) == date(21))
        #expect(Schedule.nextTransition(after: date(21, 30), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar) == date(22))
        #expect(
            Schedule.nextTransition(after: date(23), startMinutes: 22 * 60, endMinutes: 6 * 60, calendar: calendar)
                == calendar.date(byAdding: .day, value: 1, to: date(6))
        )
    }

    @Test func chinaWorkdayCalendarRecognizesOfficialSchedulesFrom2024Through2026() {
        let adjustedWorkdays = [
            chinaDate(2024, 2, 4),
            chinaDate(2024, 5, 11),
            chinaDate(2025, 1, 26),
            chinaDate(2025, 10, 11),
            chinaDate(2026, 1, 4),
            chinaDate(2026, 10, 10)
        ]
        for day in adjustedWorkdays {
            #expect(ChinaWorkdayCalendar.kind(for: day, calendar: chinaCalendar) == .adjustedWorkday)
        }

        let holidays = [
            chinaDate(2024, 2, 10),
            chinaDate(2024, 10, 7),
            chinaDate(2025, 1, 28),
            chinaDate(2025, 10, 8),
            chinaDate(2026, 2, 23),
            chinaDate(2026, 9, 25)
        ]
        for day in holidays {
            #expect(ChinaWorkdayCalendar.kind(for: day, calendar: chinaCalendar) == .publicHoliday)
        }

        #expect(ChinaWorkdayCalendar.kind(for: chinaDate(2026, 9, 23), calendar: chinaCalendar) == .regularWorkday)
        #expect(ChinaWorkdayCalendar.kind(for: chinaDate(2026, 9, 19), calendar: chinaCalendar) == .weekend)
        #expect(ChinaWorkdayCalendar.kind(for: chinaDate(2027, 1, 4), calendar: chinaCalendar) == .unsupportedWeekday(year: 2027))
        #expect(ChinaWorkdayCalendar.kind(for: chinaDate(2027, 1, 3), calendar: chinaCalendar) == .unsupportedWeekend(year: 2027))
    }

    @Test func overnightScheduleUsesTheDateOnWhichTheShiftStarted() {
        let earlyMonday = chinaDate(2026, 9, 21, 2)
        let workDate = Schedule.workDate(
            for: earlyMonday,
            startMinutes: 22 * 60,
            endMinutes: 6 * 60,
            calendar: chinaCalendar
        )
        #expect(chinaCalendar.component(.day, from: workDate) == 20)
        #expect(ChinaWorkdayCalendar.kind(for: workDate, calendar: chinaCalendar) == .adjustedWorkday)

        let atShiftEnd = chinaDate(2026, 9, 21, 6)
        let nextWorkDate = Schedule.workDate(
            for: atShiftEnd,
            startMinutes: 22 * 60,
            endMinutes: 6 * 60,
            calendar: chinaCalendar
        )
        #expect(chinaCalendar.component(.day, from: nextWorkDate) == 21)
        #expect(ChinaWorkdayCalendar.kind(for: nextWorkDate, calendar: chinaCalendar) == .regularWorkday)
    }

    @Test func oneHourScheduleUsesTheWholeInterval() {
        let result = Schedule.snapshot(now: date(9, 30), startMinutes: 9 * 60, endMinutes: 10 * 60, calendar: calendar)
        #expect(result.phase == .running)
        #expect(result.remaining == 30 * 60)
    }

    @Test func tenMinuteScheduleUsesTheWholeInterval() {
        let result = Schedule.snapshot(now: date(9, 5), startMinutes: 9 * 60, endMinutes: 9 * 60 + 10, calendar: calendar)
        #expect(result.phase == .running)
        #expect(result.remaining == 5 * 60)
    }

    @Test func thirtyMinuteScheduleRunsInsideItsClockRange() {
        let result = Schedule.snapshot(now: date(9, 15), startMinutes: 9 * 60, endMinutes: 9 * 60 + 30, calendar: calendar)
        #expect(result.phase == .running)
        #expect(result.remaining == 15 * 60)
    }

    @Test func oneMinuteScheduleKeepsSecondPrecision() {
        let result = Schedule.snapshot(now: date(9, 0, 30), startMinutes: 9 * 60, endMinutes: 9 * 60 + 1, calendar: calendar)
        #expect(result.phase == .running)
        #expect(result.remaining == 30)
    }

    @Test func previewDescriptionsFollowDaytimeSchedule() {
        #expect(PreviewStateText.description(for: .resting, startMinutes: 9 * 60, endMinutes: 18 * 60 + 20) == "待命 · 00:00–09:00")
        #expect(PreviewStateText.description(for: .focused, startMinutes: 9 * 60, endMinutes: 18 * 60 + 20) == "工作 · 09:00–18:15")
        #expect(PreviewStateText.description(for: .expectant, startMinutes: 9 * 60, endMinutes: 18 * 60 + 20) == "临近 · 18:15–18:20（结束前 5 分钟）")
        #expect(PreviewStateText.description(for: .relaxed, startMinutes: 9 * 60, endMinutes: 18 * 60 + 20) == "完成 · 18:20 后至次日 00:00")
    }

    @Test func previewDescriptionsMarkOvernightSchedule() {
        #expect(PreviewStateText.description(for: .resting, startMinutes: 22 * 60, endMinutes: 6 * 60) == "待命 · 21:00–22:00")
        #expect(PreviewStateText.description(for: .focused, startMinutes: 22 * 60, endMinutes: 6 * 60) == "工作 · 22:00–次日 05:55")
        #expect(PreviewStateText.description(for: .expectant, startMinutes: 22 * 60, endMinutes: 6 * 60) == "临近 · 次日 05:55–次日 06:00（结束前 5 分钟）")
        #expect(PreviewStateText.description(for: .relaxed, startMinutes: 22 * 60, endMinutes: 6 * 60) == "完成 · 06:00–21:00")
    }

    @Test func shortOvernightBreakKeepsBothCompletedAndWaitingStates() {
        let completed = Schedule.snapshot(now: date(21, 15), startMinutes: 22 * 60, endMinutes: 21 * 60, calendar: calendar)
        #expect(completed.phase == .finished)

        let waiting = Schedule.snapshot(now: date(21, 30), startMinutes: 22 * 60, endMinutes: 21 * 60, calendar: calendar)
        #expect(waiting.phase == .waiting)
        #expect(waiting.remaining == 30 * 60)
    }

    @Test func previewDescriptionsHandleShortSchedule() {
        #expect(PreviewStateText.description(for: .focused, startMinutes: 9 * 60, endMinutes: 9 * 60 + 3) == "工作 · 当前时段不超过 5 分钟，全程进入临近状态")
        #expect(PreviewStateText.description(for: .expectant, startMinutes: 9 * 60, endMinutes: 9 * 60 + 3) == "临近 · 09:00–09:03（结束前 3 分钟）")
    }

    @Test func scheduleHintsDistinguishDaytimeOvernightAndAllDayPlans() {
        #expect(PreviewStateText.scheduleHint(startMinutes: 9 * 60, endMinutes: 18 * 60) == "每天按此时间段自动计算，无需手动启动。")
        #expect(PreviewStateText.scheduleHint(startMinutes: 22 * 60, endMinutes: 6 * 60) == "结束时间早于开始时间，将按跨夜计划计算。")
        #expect(PreviewStateText.scheduleHint(startMinutes: 9 * 60, endMinutes: 9 * 60) == "开始与结束相同，将按连续 24 小时的全天计划计算。")
    }

    @Test @MainActor func menuBarSecondsApplyToMultiHourDurations() {
        let suiteName = "FloatProgressTests.menuBarSeconds"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60
        model.endMinutes = 18 * 60
        model.now = Calendar.current.date(byAdding: .minute, value: 13 * 60 + 30, to: today)!

        model.showSeconds = true
        #expect(model.compactStatusText == "04:30:00")

        model.showSeconds = false
        #expect(model.compactStatusText == "04:30")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func menuBarCanAdvanceIndependentlyFromTheFloatingPresentationClock() {
        let suiteName = "FloatProgressTests.independentMenuBarClock"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60
        model.endMinutes = 18 * 60
        model.now = Calendar.current.date(byAdding: .hour, value: 12, to: today)!

        let later = Calendar.current.date(
            byAdding: .second,
            value: 13 * 60 + 45,
            to: model.now
        )!
        #expect(model.compactStatusText(at: later, showSeconds: true) == "05:46:15")
        #expect(model.compactStatusText(at: later, showSeconds: false) == "05:47")
        #expect(model.calendarStatusText == "剩余 06小时00分")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func hiddenSecondsDoNotShowZeroBeforeCompletion() {
        let suiteName = "FloatProgressTests.shortRemainingWithoutSeconds"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.showSeconds = false

        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60
        model.endMinutes = 9 * 60 + 1
        model.now = Calendar.current.date(byAdding: .second, value: 30, to: Calendar.current.date(byAdding: .minute, value: 9 * 60, to: today)!)!
        #expect(model.statusText == "剩余 00小时01分")
        #expect(model.compactStatusText == "00:01")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func finalMinuteCountdownRespectsStartAndEndBoundaries() {
        let suiteName = "FloatProgressTests.finalMinuteCountdown"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentCalendarDate(2026, 9, 23))
        let start = calendar.date(byAdding: .minute, value: 9 * 60, to: today)!
        let end = calendar.date(byAdding: .minute, value: 9 * 60 + 2, to: today)!
        model.startMinutes = 9 * 60
        model.endMinutes = 9 * 60 + 2

        model.now = start.addingTimeInterval(-30)
        #expect(model.finalMinuteSeconds == nil)
        model.now = end.addingTimeInterval(-61)
        #expect(model.finalMinuteSeconds == nil)
        model.now = end.addingTimeInterval(-60)
        #expect(model.finalMinuteSeconds == 60)
        model.now = end.addingTimeInterval(-59.4)
        #expect(model.finalMinuteSeconds == 60)
        model.now = end.addingTimeInterval(-1.2)
        #expect(model.finalMinuteSeconds == 2)
        model.now = end.addingTimeInterval(-0.2)
        #expect(model.finalMinuteSeconds == 1)
        model.now = end
        #expect(model.finalMinuteSeconds == nil)
        #expect(model.snapshot.phase == .finished)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func menuBarAndFloatingCowUseTheSamePartialSecondRounding() {
        let suiteName = "FloatProgressTests.sharedCountdownRounding"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentCalendarDate(2026, 9, 23))
        let end = calendar.date(byAdding: .minute, value: 10 * 60, to: today)!
        model.startMinutes = 9 * 60
        model.endMinutes = 10 * 60
        model.showSeconds = true

        model.now = end.addingTimeInterval(-59.4)
        #expect(model.finalMinuteSeconds == 60)
        #expect(model.compactStatusText == "00:01:00")

        model.now = end.addingTimeInterval(-1.2)
        #expect(model.finalMinuteSeconds == 2)
        #expect(model.compactStatusText == "00:00:02")

        model.now = end.addingTimeInterval(-0.2)
        #expect(model.finalMinuteSeconds == 1)
        #expect(model.compactStatusText == "00:00:01")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func cowMoodChangesOnlyAtScheduleMilestones() {
        let suiteName = "FloatProgressTests.cowMood"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        let start = Calendar.current.date(byAdding: .minute, value: 9 * 60, to: today)!
        let end = start.addingTimeInterval(10 * 60)
        model.startMinutes = 9 * 60
        model.endMinutes = 9 * 60 + 10

        model.now = start.addingTimeInterval(-1)
        #expect(model.cowMood == .resting)
        model.now = start
        #expect(model.cowMood == .focused)
        model.now = end.addingTimeInterval(-301)
        #expect(model.cowMood == .focused)
        model.now = end.addingTimeInterval(-300)
        #expect(model.cowMood == .expectant)
        model.now = end.addingTimeInterval(-30)
        #expect(model.cowMood == .expectant)
        #expect(model.finalMinuteSeconds == 30)
        model.now = end
        #expect(model.cowMood == .relaxed)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func resetAppearanceKeepsContentSettings() {
        let suiteName = "FloatProgressTests.resetAppearance"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        #expect(model.accentRGB == 0x5856D6)
        model.widgetSize = 80
        model.panelOpacity = 0.5
        model.backgroundRGB = 0x112233
        model.centerLabelRGB = 0x123456
        model.waitingLabelRGB = 0x123456
        model.completedLabelRGB = 0x654321
        model.accentRGB = 0xABCDEF
        model.calendarAccentRGB = 0x123ABC
        model.showCowEars = false
        model.centerLabel = "搬砖"
        model.waitingLabel = "准备"
        model.completedLabel = "收工"

        model.resetAppearanceDefaults()

        #expect(model.widgetSize == 62)
        #expect(model.panelOpacity == 0.9)
        #expect(!model.showCowEars)
        #expect(model.backgroundRGB == 0xE9ECF5)
        #expect(model.centerLabelRGB == 0x123456)
        #expect(model.waitingLabelRGB == 0x123456)
        #expect(model.completedLabelRGB == 0x654321)
        #expect(model.accentRGB == 0x5856D6)
        #expect(model.calendarAccentRGB == 0x123ABC)
        #expect(model.centerLabel == "搬砖")
        #expect(model.waitingLabel == "准备")
        #expect(model.completedLabel == "收工")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func resetTextKeepsFloatingAppearanceSettings() {
        let suiteName = "FloatProgressTests.resetText"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.waitingLabel = "准备"
        model.centerLabel = "搬砖"
        model.completedLabel = "收工"
        model.waitingLabelRGB = 0x111111
        model.centerLabelRGB = 0x222222
        model.completedLabelRGB = 0x333333
        model.widgetSize = 80
        model.panelOpacity = 0.5
        model.backgroundRGB = 0x445566
        model.accentRGB = 0x778899

        model.resetTextDefaults()

        #expect(model.waitingLabel == "待命")
        #expect(model.centerLabel == "牛马")
        #expect(model.completedLabel == "下班")
        #expect(model.waitingLabelRGB == 0x4338CA)
        #expect(model.centerLabelRGB == 0x4338CA)
        #expect(model.completedLabelRGB == 0x059669)
        #expect(model.widgetSize == 80)
        #expect(model.panelOpacity == 0.5)
        #expect(model.backgroundRGB == 0x445566)
        #expect(model.accentRGB == 0x778899)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func countdownMasterSwitchPreservesChildDisplayPreferences() {
        let suiteName = "FloatProgressTests.countdownMasterSwitch"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        #expect(model.countdownEnabled)

        model.showFloatingPanel = true
        model.showMenuBarRemaining = true
        model.countdownEnabled = false
        #expect(!model.isFloatingPanelActive)
        #expect(!model.isMenuBarCountdownActive)
        #expect(model.showFloatingPanel)
        #expect(model.showMenuBarRemaining)

        let restored = ProgressModel(defaults: defaults)
        #expect(!restored.countdownEnabled)
        #expect(restored.showFloatingPanel)
        #expect(restored.showMenuBarRemaining)
        restored.countdownEnabled = true
        #expect(restored.isFloatingPanelActive)
        #expect(restored.isMenuBarCountdownActive)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func restTodayPausesDisplayAndExpiresTomorrow() {
        let suiteName = "FloatProgressTests.restToday"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60
        model.endMinutes = 18 * 60
        model.now = calendar.date(byAdding: .minute, value: 17 * 60 + 59, to: today)!
        #expect(model.finalMinuteSeconds == 60)

        model.toggleRestToday(at: model.now)
        #expect(model.isRestingToday)
        #expect(model.cowMood == .resting)
        #expect(model.earTime == nil)
        #expect(model.finalMinuteSeconds == nil)
        #expect(model.compactStatusText == "休息")
        #expect(model.statusText == "休息")
        let restoredWhileResting = ProgressModel(defaults: defaults)
        restoredWhileResting.now = model.now
        #expect(restoredWhileResting.isRestingToday)

        model.now = calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(!model.isRestingToday)
        #expect(model.cowMood == .resting)
        #expect(model.earTime != nil)
        #expect(model.compactStatusText != "休息")
        #expect(model.startMinutes == 9 * 60)
        #expect(model.endMinutes == 18 * 60)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func restTodayCanBeCancelledAndWaitingColorIsIndependent() {
        let suiteName = "FloatProgressTests.waitingColor"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.now = currentCalendarDate(2026, 9, 23)
        #expect(model.waitingLabel == "待命")
        #expect(model.waitingLabelRGB == 0x4338CA)
        model.waitingLabel = "候场"
        model.waitingLabelRGB = 0xAABBCC
        #expect(model.centerLabelRGB == 0x4338CA)

        model.toggleRestToday(at: model.now)
        #expect(model.isRestingToday)
        model.toggleRestToday(at: model.now)
        #expect(!model.isRestingToday)
        let restored = ProgressModel(defaults: defaults)
        restored.now = model.now
        #expect(!restored.isRestingToday)
        #expect(restored.waitingLabel == "候场")
        #expect(restored.waitingLabelRGB == 0xAABBCC)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func smartWorkdaysRestOnHolidaysAndAllowATemporaryWorkOverride() {
        let suiteName = "FloatProgressTests.smartWorkdays"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.startMinutes = 9 * 60
        model.endMinutes = 18 * 60

        model.now = currentCalendarDate(2026, 10, 2)
        #expect(model.chinaWorkdayKind == .publicHoliday)
        #expect(model.isAutomaticRestDay)
        #expect(model.isRestingToday)
        #expect(model.cowMood == .resting)
        #expect(model.earTime == nil)
        #expect(model.todayOverrideMenuTitle == "今天上班")

        model.toggleRestToday(at: model.now)
        #expect(!model.isRestingToday)
        #expect(model.workUntil != nil)
        #expect(model.todayOverrideMenuTitle == "恢复自动休息")

        model.toggleRestToday(at: model.now)
        #expect(model.workUntil == nil)
        #expect(model.isRestingToday)

        model.now = currentCalendarDate(2026, 9, 12)
        #expect(model.chinaWorkdayKind == .weekend)
        #expect(model.todayOverrideMenuTitle == "今天上班")
        model.toggleRestToday(at: model.now)
        #expect(!model.isRestingToday)
        #expect(model.todayOverrideMenuTitle == "恢复自动休息")
        model.toggleRestToday(at: model.now)

        model.now = currentCalendarDate(2026, 10, 10)
        #expect(model.chinaWorkdayKind == .adjustedWorkday)
        #expect(!model.isAutomaticRestDay)
        #expect(!model.isRestingToday)
        #expect(model.todayOverrideMenuTitle == "今天休息")

        model.toggleRestToday(at: model.now)
        #expect(model.isRestingToday)
        #expect(model.restUntil != nil)
        #expect(model.todayOverrideMenuTitle == "恢复自动安排")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func smartWorkdaysAreBuiltInAndRemoveTheLegacyPreference() {
        let suiteName = "FloatProgressTests.smartWorkdaysPreference"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(false, forKey: "useChinaWorkdays")

        let model = ProgressModel(defaults: defaults)
        model.now = currentCalendarDate(2026, 10, 2)
        #expect(model.isRestingToday)
        #expect(defaults.object(forKey: "useChinaWorkdays") == nil)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func overnightRestCoversTheWholeRelevantShift() {
        let beforeEnd = ProgressModel.restDeadline(
            now: date(2),
            startMinutes: 22 * 60,
            endMinutes: 6 * 60,
            calendar: calendar
        )
        #expect(beforeEnd == date(6))

        let betweenShifts = ProgressModel.restDeadline(
            now: date(12),
            startMinutes: 22 * 60,
            endMinutes: 6 * 60,
            calendar: calendar
        )
        #expect(betweenShifts == calendar.date(byAdding: .day, value: 1, to: date(6)))

        let afterStart = ProgressModel.restDeadline(
            now: date(23),
            startMinutes: 22 * 60,
            endMinutes: 6 * 60,
            calendar: calendar
        )
        #expect(afterStart == calendar.date(byAdding: .day, value: 1, to: date(6)))
    }

    @Test @MainActor func daytimeRestExpiresAtNextMidnight() {
        let deadline = ProgressModel.restDeadline(
            now: date(13),
            startMinutes: 9 * 60,
            endMinutes: 18 * 60,
            calendar: calendar
        )
        #expect(deadline == calendar.date(byAdding: .day, value: 1, to: date(0)))
    }

    @Test @MainActor func cowEarsStayInsidePanelAtEverySupportedSize() {
        let suiteName = "FloatProgressTests.cowPanelBounds"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        for size in stride(from: 40.0, through: 88.0, by: 2.0) {
            model.widgetSize = size
            let side = CGFloat(size)
            let earReach = side * (CowLayout.earCenterOffset + CowLayout.earWidth * (0.5 + CowLayout.earOverhang))
            let outlineHalfWidth = max(side * 0.020, 1.1) / 2
            #expect(model.effectivePanelSize.width / 2 >= earReach + outlineHalfWidth + 2)
            #expect(model.effectivePanelSize.height == side)
            model.showCowEars = false
            #expect(model.effectivePanelSize.width == side)
            model.showCowEars = true
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func cowEarsAndCoreHoverTime() {
        let suiteName = "FloatProgressTests.cowHoverTime"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        #expect(model.widgetSize == 62)
        #expect(model.showCowEars)
        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60
        model.endMinutes = 11 * 60
        model.now = Calendar.current.date(byAdding: .second, value: 9 * 3600 + 30 * 60 + 45, to: today)!
        #expect(model.coreHoverTime == "15")
        #expect(model.earTime?.hours == "01")
        #expect(model.earTime?.minutes == "30")

        model.setCoreHovered(true)
        model.now = Calendar.current.date(byAdding: .second, value: 9 * 3600 + 30 * 60 + 45, to: today)!
        #expect(model.earTime?.hours == "01")
        #expect(model.earTime?.minutes == "29")

        model.showCowEars = false
        #expect(model.coreHoverTime == "01:29")
        model.now = Calendar.current.date(byAdding: .second, value: 10 * 3600 + 59 * 60 + 15, to: today)!
        #expect(model.coreHoverTime == "00:45")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func waitingEarsShowStartTimeAndHoverShowsPreciseCountdown() {
        let suiteName = "FloatProgressTests.cowWaitingEars"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60 + 5
        model.endMinutes = 18 * 60
        model.now = Calendar.current.date(byAdding: .minute, value: 8 * 60 + 35, to: today)!

        #expect(model.earTime?.hours == "09")
        #expect(model.earTime?.minutes == "05")
        #expect(model.coreHoverTime == "00")
        #expect(model.coreHoverHasTime)

        model.setCoreHovered(true)
        model.now = Calendar.current.date(byAdding: .minute, value: 8 * 60 + 35, to: today)!
        #expect(model.earTime?.hours == "00")
        #expect(model.earTime?.minutes == "30")

        model.setCoreHovered(false)
        model.now = Calendar.current.date(byAdding: .minute, value: 8 * 60 + 35, to: today)!
        #expect(model.earTime?.hours == "09")
        #expect(model.earTime?.minutes == "05")

        model.now = Calendar.current.date(byAdding: .minute, value: 18 * 60, to: today)!
        #expect(!model.coreHoverHasTime)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func panelPositionLockPersists() {
        let suiteName = "FloatProgressTests.panelPositionLock"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        #expect(!model.lockPanelPosition)

        model.lockPanelPosition = true

        #expect(ProgressModel(defaults: defaults).lockPanelPosition)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func opticalSizingAddsDetailOnlyAsSpaceAllows() {
        let compact = CowOptics.values(for: 40)
        let regular = CowOptics.values(for: 62)
        let spacious = CowOptics.values(for: 88)

        #expect(compact.headWidth > regular.headWidth)
        #expect(regular.headWidth > spacious.headWidth)
        #expect(compact.focusedEyeDiameter > regular.focusedEyeDiameter)
        #expect(regular.focusedEyeDiameter > spacious.focusedEyeDiameter)
        #expect(compact.outlineRatio > spacious.outlineRatio)
        #expect(compact.nostrilDiameter > regular.nostrilDiameter)
        #expect(regular.nostrilDiameter > spacious.nostrilDiameter)
        #expect(compact.expressionStrokeRatio > regular.expressionStrokeRatio)
        #expect(regular.expressionStrokeRatio > spacious.expressionStrokeRatio)
        #expect(compact.earLabelRatio > spacious.earLabelRatio)
        #expect(abs(CowOptics.values(for: 61.99).headWidth - CowOptics.values(for: 62.01).headWidth) < 0.001)
        #expect(abs(CowOptics.values(for: 61.99).nostrilDiameter - CowOptics.values(for: 62.01).nostrilDiameter) < 0.001)
    }

    @Test @MainActor func statusBarCalendarIconShowsTheCurrentDayAsATemplateImage() {
        let iconDate = chinaDate(2026, 9, 24)
        let icon = StatusBarCalendarIcon.image(for: iconDate, calendar: chinaCalendar)
        #expect(icon.isTemplate)
        #expect(icon.size.width == 19)
        #expect(icon.size.height == 18)
        #expect(icon.accessibilityDescription == "日历，24日")
        #expect(StatusBarCalendarIcon.countdownFont === StatusBarCalendarIcon.countdownFont)

        let attributes: [NSAttributedString.Key: Any] = [.font: StatusBarCalendarIcon.countdownFont]
        let narrowDigits = NSAttributedString(string: " 11:11:11", attributes: attributes).size().width
        let wideDigits = NSAttributedString(string: " 88:88:88", attributes: attributes).size().width
        #expect(abs(narrowDigits - wideDigits) < 0.001)

    }

    @Test func calendarMonthBuildsAMondayFirstSixWeekGrid() {
        let february = CalendarMonth.make(containing: chinaDate(2024, 2, 15), calendar: chinaCalendar)
        #expect(february.days.count == 42)
        #expect(february.days.filter(\.isInDisplayedMonth).count == 29)
        #expect(chinaCalendar.component(.weekday, from: february.days.first!.date) == 2)
        #expect(chinaCalendar.component(.weekday, from: february.days.last!.date) == 1)
        #expect(february.workdayCount + february.restDayCount == 29)
    }

    @Test func calendarMonthCanUseSundayAsTheFirstWeekday() {
        let february = CalendarMonth.make(
            containing: chinaDate(2024, 2, 15),
            firstWeekday: 1,
            calendar: chinaCalendar
        )
        #expect(february.days.count == 42)
        #expect(chinaCalendar.component(.weekday, from: february.days.first!.date) == 1)
        #expect(chinaCalendar.component(.weekday, from: february.days.last!.date) == 7)
    }

    @Test func calendarMonthSelectionIsLimitedToTheSupportedSolarTermRange() {
        #expect(CalendarMonth.supportedYears == 1900...2100)
        #expect(CalendarMonth.monthStart(year: 1900, month: 1, calendar: chinaCalendar) == chinaDate(1900, 1, 1, 0))
        #expect(CalendarMonth.monthStart(year: 2100, month: 12, calendar: chinaCalendar) == chinaDate(2100, 12, 1, 0))
        #expect(CalendarMonth.monthStart(year: 1899, month: 12, calendar: chinaCalendar) == nil)
        #expect(CalendarMonth.monthStart(year: 2101, month: 1, calendar: chinaCalendar) == nil)
        #expect(CalendarMonth.monthStart(year: 2026, month: 13, calendar: chinaCalendar) == nil)
    }

    @Test func returningToTheCurrentMonthSelectsToday() {
        let today = chinaDate(2026, 9, 28, 18)
        let currentMonth = chinaDate(2026, 9, 1, 0)
        let otherMonth = chinaDate(2026, 8, 1, 0)

        #expect(
            CalendarMonth.selectionDate(
                forDisplayedMonth: currentMonth,
                today: today,
                calendar: chinaCalendar
            ) == chinaDate(2026, 9, 28, 0)
        )
        #expect(
            CalendarMonth.selectionDate(
                forDisplayedMonth: otherMonth,
                today: today,
                calendar: chinaCalendar
            ) == otherMonth
        )
    }

    @Test @MainActor func calendarDisplayPreferencesPersistButSelectedSettingsTabDoesNot() {
        let suiteName = "FloatProgressTests.calendarPreferences"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        #expect(model.settingsTab == .calendar)

        model.calendarFirstWeekday = 1
        model.showLunarDetails = false
        model.showWorkdayBadges = false
        model.showMonthSummary = false
        model.showMenuBarRemaining = false
        model.calendarAccentRGB = 0x2563EB
        model.settingsTab = .countdown

        let restored = ProgressModel(defaults: defaults)
        #expect(restored.calendarFirstWeekday == 1)
        #expect(!restored.showLunarDetails)
        #expect(!restored.showWorkdayBadges)
        #expect(!restored.showMonthSummary)
        #expect(!restored.showMenuBarRemaining)
        #expect(restored.calendarAccentRGB == 0x2563EB)
        #expect(restored.accentRGB == 0x5856D6)
        #expect(restored.settingsTab == .calendar)

        model.settingsTab = .about
        #expect(ProgressModel(defaults: defaults).settingsTab == .calendar)

        restored.resetCalendarDisplayDefaults()
        #expect(restored.calendarFirstWeekday == 2)
        #expect(restored.showLunarDetails)
        #expect(restored.showWorkdayBadges)
        #expect(restored.showMonthSummary)
        #expect(!restored.showMenuBarRemaining)
        #expect(restored.calendarAccentRGB == 0x5856D6)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func appVersionComparisonHandlesReleaseTagsAndMissingComponents() {
        #expect(AppVersionComparison.isNewer("v3.0.1", than: "3.0.0"))
        #expect(AppVersionComparison.isNewer("3.1", than: "3.0.9"))
        #expect(!AppVersionComparison.isNewer("3.0", than: "3.0.0"))
        #expect(!AppVersionComparison.isNewer("v2.9.9", than: "3.0.0"))
        #expect(!AppVersionComparison.isNewer("未知", than: "3.0.0"))
    }

    @Test func updateDownloadPrefersUniversalArchiveAndMatchingChecksum() throws {
        let intel = AppReleaseAsset(
            name: "牛马日历-Intel.zip",
            downloadURL: URL(string: "https://example.com/intel.zip")!
        )
        let universal = AppReleaseAsset(
            name: "牛马日历-macOS-Universal.zip",
            downloadURL: URL(string: "https://example.com/universal.zip")!
        )
        let checksum = AppReleaseAsset(
            name: "牛马日历-macOS-Universal.zip.sha256",
            downloadURL: URL(string: "https://example.com/universal.sha256")!
        )

        let selected = AppUpdateChecker.preferredDownloadAssets(in: [intel, checksum, universal])
        #expect(selected?.archive == universal)
        #expect(selected?.checksum == checksum)

        let hash = String(repeating: "a", count: 64)
        #expect(try AppUpdateChecker.expectedSHA256(from: Data("\(hash)  package.zip\n".utf8)) == hash)
        #expect(throws: AppUpdateError.self) {
            try AppUpdateChecker.expectedSHA256(from: Data("not-a-checksum".utf8))
        }
    }

    @Test func calendarDaysCombineLunarTermsAndOfficialWorkdayMarkers() {
        let february = CalendarMonth.make(containing: chinaDate(2026, 2, 17), calendar: chinaCalendar)
        let springFestival = february.days.first { chinaCalendar.isDate($0.date, inSameDayAs: chinaDate(2026, 2, 17)) }
        #expect(springFestival?.festival == "春节")
        #expect(springFestival?.workdayKind == .publicHoliday)

        let september = CalendarMonth.make(containing: chinaDate(2026, 9, 23), calendar: chinaCalendar)
        let autumnEquinox = september.days.first { chinaCalendar.isDate($0.date, inSameDayAs: chinaDate(2026, 9, 23)) }
        let makeupDay = september.days.first { chinaCalendar.isDate($0.date, inSameDayAs: chinaDate(2026, 9, 20)) }
        #expect(autumnEquinox?.solarTerm == "秋分")
        #expect(makeupDay?.workdayKind == .adjustedWorkday)
        #expect(CalendarMonth.nextOfficialRestDay(after: chinaDate(2026, 9, 24), calendar: chinaCalendar) == chinaDate(2026, 9, 25, 0))
        #expect(ChineseCalendarText.fullText(for: chinaDate(2026, 9, 24), calendar: chinaCalendar) == "丙午年（马）八月十四")
    }

    @Test func appearanceContrastWarnsWithoutChangingColors() {
        #expect(abs(AppearanceContrast.ratio(0x000000, 0xFFFFFF) - 21) < 0.001)
        #expect(AppearanceContrast.ratio(0x5856D6, 0x5856D6) == 1)
        #expect(
            AppearanceContrast.warning(
                backgroundRGB: 0xE9ECF5,
                waitingRGB: 0x4338CA,
                workingRGB: 0x4338CA,
                completedRGB: 0x059669,
                accentRGB: 0x5856D6
            ) == nil
        )
        #expect(
            AppearanceContrast.warning(
                backgroundRGB: 0xFFFFFF,
                waitingRGB: 0xFFFFFF,
                workingRGB: 0x000000,
                completedRGB: 0x000000,
                accentRGB: 0x000000
            ) == "待命文字与牛头底色对比偏低，可能看不清。"
        )
        #expect(
            AppearanceContrast.warning(
                backgroundRGB: 0xFFFFFF,
                waitingRGB: 0x000000,
                workingRGB: 0x000000,
                completedRGB: 0x000000,
                accentRGB: 0xFFFFFF
            ) == "牛角与面部点缀和牛头底色过于接近，轮廓可能不明显。"
        )
    }

    @Test @MainActor func cowEarsShowRemainingHoursAndMinutes() {
        let suiteName = "FloatProgressTests.cowEars"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let today = Calendar.current.startOfDay(for: currentCalendarDate(2026, 9, 23))
        model.startMinutes = 9 * 60
        model.endMinutes = 10 * 60 + 45
        model.now = Calendar.current.date(byAdding: .minute, value: 9 * 60 + 30, to: today)!

        #expect(model.earTime?.hours == "01")
        #expect(model.earTime?.minutes == "15")

        model.now = Calendar.current.date(byAdding: .second, value: -30, to: Calendar.current.date(byAdding: .minute, value: 10 * 60 + 45, to: today)!)!
        #expect(model.finalMinuteSeconds == 30)
        #expect(model.earTime == nil)

        model.now = Calendar.current.date(byAdding: .second, value: -61, to: Calendar.current.date(byAdding: .minute, value: 10 * 60 + 45, to: today)!)!
        #expect(model.finalMinuteSeconds == nil)
        #expect(model.earTime?.hours == "00")
        #expect(model.earTime?.minutes == "02")

        model.now = Calendar.current.date(byAdding: .second, value: -60, to: Calendar.current.date(byAdding: .minute, value: 10 * 60 + 45, to: today)!)!
        #expect(model.finalMinuteSeconds == 60)
        #expect(model.earTime == nil)

        model.now = Calendar.current.date(byAdding: .minute, value: 10 * 60 + 45, to: today)!
        #expect(model.earTime == nil)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func finalMinuteOwnsTheDisplayAcrossHoverAndEarModes() {
        let suiteName = "FloatProgressTests.finalMinuteDisplayOwnership"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentCalendarDate(2026, 9, 23))
        let end = calendar.date(byAdding: .minute, value: 10 * 60, to: today)!
        model.startMinutes = 9 * 60
        model.endMinutes = 10 * 60

        model.now = end.addingTimeInterval(-61)
        #expect(model.finalMinuteSeconds == nil)
        #expect(model.earTime?.hours == "00")
        #expect(model.earTime?.minutes == "02")

        model.setCoreHovered(true)
        model.now = end.addingTimeInterval(-61)
        #expect(model.earTime?.hours == "00")
        #expect(model.earTime?.minutes == "01")
        #expect(model.coreHoverTime == "01")

        model.now = end.addingTimeInterval(-60)
        #expect(model.finalMinuteSeconds == 60)
        #expect(model.earTime == nil)
        model.now = end.addingTimeInterval(-59)
        #expect(model.finalMinuteSeconds == 59)
        #expect(model.earTime == nil)
        model.now = end.addingTimeInterval(-1)
        #expect(model.finalMinuteSeconds == 1)
        #expect(model.earTime == nil)

        model.showCowEars = false
        model.now = end.addingTimeInterval(-61)
        #expect(model.coreHoverTime == "01:01")
        #expect(model.finalMinuteSeconds == nil)
        model.now = end.addingTimeInterval(-60)
        #expect(model.finalMinuteSeconds == 60)

        model.now = end
        #expect(model.finalMinuteSeconds == nil)
        #expect(model.snapshot.phase == .finished)
        #expect(!model.coreHoverHasTime)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func overnightFinalMinuteUsesTheSameSixtyToOneBoundary() {
        let suiteName = "FloatProgressTests.overnightFinalMinute"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentCalendarDate(2026, 9, 23))
        let end = calendar.date(byAdding: .minute, value: 6 * 60, to: today)!
        model.startMinutes = 22 * 60
        model.endMinutes = 6 * 60

        model.now = end.addingTimeInterval(-61)
        #expect(model.snapshot.phase == .running)
        #expect(model.finalMinuteSeconds == nil)
        #expect(model.earTime?.minutes == "02")
        model.now = end.addingTimeInterval(-60)
        #expect(model.finalMinuteSeconds == 60)
        #expect(model.earTime == nil)
        model.now = end.addingTimeInterval(-59)
        #expect(model.finalMinuteSeconds == 59)
        model.now = end.addingTimeInterval(-1)
        #expect(model.finalMinuteSeconds == 1)
        model.now = end
        #expect(model.snapshot.phase == .finished)
        #expect(model.finalMinuteSeconds == nil)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func timeResynchronizationRealignsActiveRestAndClearsExpiredRest() {
        let suiteName = "FloatProgressTests.timeResynchronization"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentCalendarDate(2026, 9, 23))
        let afternoon = calendar.date(byAdding: .hour, value: 13, to: today)!
        let oldDeadline = calendar.date(byAdding: .day, value: 2, to: today)!
        defaults.set(9 * 60, forKey: "startMinutes")
        defaults.set(18 * 60, forKey: "endMinutes")
        defaults.set(oldDeadline, forKey: "restUntil")
        let model = ProgressModel(defaults: defaults)

        model.resynchronizeAfterSystemTimeChange(at: afternoon)
        let expectedMidnight = calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(model.now == afternoon)
        #expect(model.restUntil == expectedMidnight)
        #expect(model.isRestingToday)

        model.refresh(at: expectedMidnight)
        #expect(model.restUntil == nil)
        #expect(!model.isRestingToday)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func startupRepairsCorruptPreferencesAndRecordsSchemaVersion() {
        let suiteName = "FloatProgressTests.preferenceRepair"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(-1, forKey: "startMinutes")
        defaults.set(2_000, forKey: "endMinutes")
        defaults.set(999.0, forKey: "circleSize")
        defaults.set(Double.nan, forKey: "panelOpacity")
        defaults.set("一二三四五六七八", forKey: "waitingLabel")
        defaults.set("ABCDEFGHI", forKey: "centerLabel")
        defaults.set(-1, forKey: "waitingLabelRGB")
        defaults.set(0x1FFFFFF, forKey: "completedLabelRGB")
        defaults.set(-99, forKey: "backgroundRGB")
        defaults.set(0x1000000, forKey: "progressRGB")
        defaults.set(1, forKey: "textColorVersion")

        let model = ProgressModel(defaults: defaults)

        #expect(model.startMinutes == 9 * 60)
        #expect(model.endMinutes == 18 * 60)
        #expect(model.widgetSize == 88)
        #expect(model.panelOpacity == 0.9)
        #expect(model.waitingLabel == "一二三四五六")
        #expect(model.centerLabel == "ABCDEF")
        #expect(model.waitingLabelRGB == 0x4338CA)
        #expect(model.completedLabelRGB == 0x059669)
        #expect(model.backgroundRGB == 0xE9ECF5)
        #expect(model.accentRGB == 0x5856D6)
        #expect(defaults.integer(forKey: "settingsSchemaVersion") == ProgressModel.currentSettingsSchemaVersion)
        #expect(defaults.double(forKey: "circleSize") == 88)
        #expect(defaults.string(forKey: "waitingLabel") == "一二三四五六")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func startupPreservesValidCustomPreferences() {
        let suiteName = "FloatProgressTests.preferencePreservation"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(0, forKey: "startMinutes")
        defaults.set(23 * 60 + 59, forKey: "endMinutes")
        defaults.set(41.5, forKey: "circleSize")
        defaults.set(0.73, forKey: "panelOpacity")
        defaults.set("", forKey: "centerLabel")
        defaults.set(0x000000, forKey: "centerLabelRGB")
        defaults.set(1, forKey: "textColorVersion")

        let model = ProgressModel(defaults: defaults)

        #expect(model.startMinutes == 0)
        #expect(model.endMinutes == 23 * 60 + 59)
        #expect(model.widgetSize == 41.5)
        #expect(model.panelOpacity == 0.73)
        #expect(model.centerLabel.isEmpty)
        #expect(model.centerLabelRGB == 0x000000)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func reduceTransparencyOverridesWithoutChangingSavedOpacity() {
        #expect(AccessibilityAppearance.panelOpacity(userOpacity: 0.55, reduceTransparency: false) == 0.55)
        #expect(AccessibilityAppearance.panelOpacity(userOpacity: 0.55, reduceTransparency: true) == 1)
    }

}
