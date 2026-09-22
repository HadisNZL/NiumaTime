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

    @Test func runningDaySchedule() {
        let result = Schedule.snapshot(now: date(13, 30), startMinutes: 9 * 60, endMinutes: 18 * 60, calendar: calendar)
        #expect(result.phase == .running)
        #expect(abs(result.progress - 0.5) < 0.001)
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
        #expect(abs(result.progress - 0.5) < 0.001)
        #expect(result.remaining == 4 * 3600)
    }

    @Test func oneHourScheduleUsesTheWholeInterval() {
        let result = Schedule.snapshot(now: date(9, 30), startMinutes: 9 * 60, endMinutes: 10 * 60, calendar: calendar)
        #expect(result.phase == .running)
        #expect(abs(result.progress - 0.5) < 0.001)
        #expect(result.remaining == 30 * 60)
    }

    @Test func tenMinuteScheduleUsesTheWholeInterval() {
        let result = Schedule.snapshot(now: date(9, 5), startMinutes: 9 * 60, endMinutes: 9 * 60 + 10, calendar: calendar)
        #expect(result.phase == .running)
        #expect(abs(result.progress - 0.5) < 0.001)
        #expect(result.remaining == 5 * 60)
    }

    @Test func thirtyMinuteScheduleRunsInsideItsClockRange() {
        let result = Schedule.snapshot(now: date(9, 15), startMinutes: 9 * 60, endMinutes: 9 * 60 + 30, calendar: calendar)
        #expect(result.phase == .running)
        #expect(abs(result.progress - 0.5) < 0.001)
        #expect(result.remaining == 15 * 60)
    }

    @Test func oneMinuteScheduleKeepsSecondPrecision() {
        let result = Schedule.snapshot(now: date(9, 0, 30), startMinutes: 9 * 60, endMinutes: 9 * 60 + 1, calendar: calendar)
        #expect(result.phase == .running)
        #expect(abs(result.progress - 0.5) < 0.001)
        #expect(result.remaining == 30)
    }

    @Test @MainActor func menuBarSecondsApplyToMultiHourDurations() {
        let suiteName = "FloatProgressTests.menuBarSeconds"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let today = Calendar.current.startOfDay(for: Date())
        model.startMinutes = 9 * 60
        model.endMinutes = 18 * 60
        model.now = Calendar.current.date(byAdding: .minute, value: 13 * 60 + 30, to: today)!

        model.showSeconds = true
        #expect(model.compactStatusText == "04:30:00")

        model.showSeconds = false
        #expect(model.compactStatusText == "04:30")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func hiddenSecondsDoNotShowZeroBeforeCompletion() {
        let suiteName = "FloatProgressTests.shortRemainingWithoutSeconds"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.showSeconds = false

        #expect(model.format(59) == "00小时01分")

        let today = Calendar.current.startOfDay(for: Date())
        model.startMinutes = 9 * 60
        model.endMinutes = 9 * 60 + 1
        model.now = Calendar.current.date(byAdding: .second, value: 30, to: Calendar.current.date(byAdding: .minute, value: 9 * 60, to: today)!)!
        #expect(model.compactStatusText == "00:01")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func finalMinuteCountdownRespectsStartAndEndBoundaries() {
        let suiteName = "FloatProgressTests.finalMinuteCountdown"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
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

    @Test @MainActor func resetAppearanceKeepsContentSettings() {
        let suiteName = "FloatProgressTests.resetAppearance"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.circleSize = 80
        model.backgroundRGB = 0x112233
        model.centerLabelRGB = 0x123456
        model.completedLabelRGB = 0x654321
        model.progressOpacity = 0.25
        model.trackOpacity = 0.80
        model.beaconRGB = 0xABCDEF
        model.beaconDiameter = 9
        model.centerLabel = "搬砖"

        model.resetAppearanceDefaults()

        #expect(model.circleSize == 56)
        #expect(model.backgroundRGB == 0xE9ECF5)
        #expect(model.centerLabelRGB == 0x4338CA)
        #expect(model.completedLabelRGB == 0x059669)
        #expect(model.progressOpacity == 1.0)
        #expect(model.trackOpacity == 0.30)
        #expect(model.beaconRGB == 0x5856D6)
        #expect(model.beaconDiameter == 8.0)
        #expect(model.centerLabel == "搬砖")
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test @MainActor func largeBeaconExpandsWindowWithoutChangingOrbitSize() {
        let suiteName = "FloatProgressTests.largeBeaconBounds"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let model = ProgressModel(defaults: defaults)
        model.circleSize = 40
        model.beaconDiameter = 18

        #expect(abs(model.effectiveWidgetSize - 51.2) < 0.001)

        model.beaconDiameter = 3
        #expect(model.effectiveWidgetSize == 40)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
