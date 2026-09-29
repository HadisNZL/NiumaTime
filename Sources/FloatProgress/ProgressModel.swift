import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

enum CowMood: Hashable {
    case resting
    case focused
    case expectant
    case relaxed
}

enum SettingsTab: Hashable {
    case calendar
    case countdown
    case about
}

@MainActor
final class ProgressModel: ObservableObject {
    private enum Key {
        static let settingsSchemaVersion = "settingsSchemaVersion"
        static let countdownEnabled = "countdownEnabled"
        static let startMinutes = "startMinutes"
        static let endMinutes = "endMinutes"
        // Keep the existing preference keys so updates preserve each user's appearance.
        static let widgetSize = "circleSize"
        static let showCowEars = "showCowEars"
        static let waitingLabel = "waitingLabel"
        static let centerLabel = "centerLabel"
        static let completedLabel = "completedLabel"
        static let waitingLabelRGB = "waitingLabelRGB"
        static let centerLabelRGB = "centerLabelRGB"
        static let completedLabelRGB = "completedLabelRGB"
        static let textColorVersion = "textColorVersion"
        static let showSeconds = "showSeconds"
        static let showFloatingPanel = "showFloatingPanel"
        static let showMenuBarRemaining = "showMenuBarRemaining"
        static let calendarFirstWeekday = "calendarFirstWeekday"
        static let showLunarDetails = "showLunarDetails"
        static let showWorkdayBadges = "showWorkdayBadges"
        static let showMonthSummary = "showMonthSummary"
        static let calendarAccentRGB = "calendarAccentRGB"
        static let lockPanelPosition = "lockPanelPosition"
        static let panelOpacity = "panelOpacity"
        static let backgroundRGB = "backgroundRGB"
        static let accentRGB = "progressRGB"
        static let restUntil = "restUntil"
        static let workUntil = "workUntil"
        // Legacy key from the first one-day-rest implementation.
        static let restDay = "restDay"
    }

    static let currentSettingsSchemaVersion = 7

    private enum DefaultValue {
        static let startMinutes = 9 * 60
        static let endMinutes = 18 * 60
        static let widgetSize = 62.0
        static let panelOpacity = 0.90
        static let waitingLabel = "待命"
        static let centerLabel = "牛马"
        static let completedLabel = "下班"
        static let waitingLabelRGB = 0x4338CA
        static let centerLabelRGB = 0x4338CA
        static let completedLabelRGB = 0x059669
        static let backgroundRGB = 0xE9ECF5
        static let accentRGB = 0x5856D6
        static let calendarAccentRGB = 0x5856D6
    }

    private let defaults: UserDefaults
    private var timer: Timer?
    private var isCoreHovered = false
    private var isCalendarPresented = false
    private var isSettingsPresented = false

    @Published var now = Date()
    @Published var countdownEnabled: Bool {
        didSet {
            defaults.set(countdownEnabled, forKey: Key.countdownEnabled)
            if !countdownEnabled { isCoreHovered = false }
            scheduleNextRefresh()
        }
    }
    @Published var startMinutes: Int { didSet { defaults.set(startMinutes, forKey: Key.startMinutes); refresh() } }
    @Published var endMinutes: Int { didSet { defaults.set(endMinutes, forKey: Key.endMinutes); refresh() } }
    @Published var widgetSize: Double { didSet { defaults.set(widgetSize, forKey: Key.widgetSize) } }
    @Published var showCowEars: Bool { didSet { defaults.set(showCowEars, forKey: Key.showCowEars); scheduleNextRefresh() } }
    @Published var waitingLabel: String { didSet { defaults.set(waitingLabel, forKey: Key.waitingLabel) } }
    @Published var centerLabel: String { didSet { defaults.set(centerLabel, forKey: Key.centerLabel) } }
    @Published var completedLabel: String { didSet { defaults.set(completedLabel, forKey: Key.completedLabel) } }
    @Published var waitingLabelRGB: Int { didSet { defaults.set(waitingLabelRGB, forKey: Key.waitingLabelRGB) } }
    @Published var centerLabelRGB: Int { didSet { defaults.set(centerLabelRGB, forKey: Key.centerLabelRGB) } }
    @Published var completedLabelRGB: Int { didSet { defaults.set(completedLabelRGB, forKey: Key.completedLabelRGB) } }
    @Published var showSeconds: Bool { didSet { defaults.set(showSeconds, forKey: Key.showSeconds); scheduleNextRefresh() } }
    @Published var showFloatingPanel: Bool {
        didSet {
            defaults.set(showFloatingPanel, forKey: Key.showFloatingPanel)
            if !showFloatingPanel { isCoreHovered = false }
            scheduleNextRefresh()
        }
    }
    @Published var showMenuBarRemaining: Bool { didSet { defaults.set(showMenuBarRemaining, forKey: Key.showMenuBarRemaining); scheduleNextRefresh() } }
    @Published var calendarFirstWeekday: Int { didSet { defaults.set(calendarFirstWeekday, forKey: Key.calendarFirstWeekday) } }
    @Published var showLunarDetails: Bool { didSet { defaults.set(showLunarDetails, forKey: Key.showLunarDetails) } }
    @Published var showWorkdayBadges: Bool { didSet { defaults.set(showWorkdayBadges, forKey: Key.showWorkdayBadges) } }
    @Published var showMonthSummary: Bool { didSet { defaults.set(showMonthSummary, forKey: Key.showMonthSummary) } }
    @Published var calendarAccentRGB: Int { didSet { defaults.set(calendarAccentRGB, forKey: Key.calendarAccentRGB) } }
    @Published var settingsTab: SettingsTab = .calendar
    @Published var lockPanelPosition: Bool { didSet { defaults.set(lockPanelPosition, forKey: Key.lockPanelPosition) } }
    @Published var panelOpacity: Double { didSet { defaults.set(panelOpacity, forKey: Key.panelOpacity) } }
    @Published var backgroundRGB: Int { didSet { defaults.set(backgroundRGB, forKey: Key.backgroundRGB) } }
    @Published var accentRGB: Int { didSet { defaults.set(accentRGB, forKey: Key.accentRGB) } }
    @Published private(set) var restUntil: Date? {
        didSet {
            if let restUntil {
                defaults.set(restUntil, forKey: Key.restUntil)
            } else {
                defaults.removeObject(forKey: Key.restUntil)
            }
        }
    }
    @Published private(set) var workUntil: Date? {
        didSet {
            if let workUntil {
                defaults.set(workUntil, forKey: Key.workUntil)
            } else {
                defaults.removeObject(forKey: Key.workUntil)
            }
        }
    }
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginNeedsApproval: Bool
    @Published private(set) var launchAtLoginError: String?

    private var isManualRestActive: Bool {
        restUntil.map { now < $0 } ?? false
    }

    private var isManualWorkActive: Bool {
        workUntil.map { now < $0 } ?? false
    }

    var scheduleWorkDate: Date {
        Schedule.workDate(for: now, startMinutes: startMinutes, endMinutes: endMinutes)
    }

    var chinaWorkdayKind: ChinaWorkdayKind {
        ChinaWorkdayCalendar.kind(for: scheduleWorkDate)
    }

    var isAutomaticRestDay: Bool {
        !chinaWorkdayKind.isWorkday
    }

    var isRestingToday: Bool {
        if isManualWorkActive { return false }
        if isManualRestActive { return true }
        return isAutomaticRestDay
    }

    func toggleRestToday(at date: Date = Date()) {
        now = date
        if isManualRestActive || isManualWorkActive {
            restUntil = nil
            workUntil = nil
        } else if isAutomaticRestDay {
            restUntil = nil
            workUntil = Self.restDeadline(now: now, startMinutes: startMinutes, endMinutes: endMinutes)
        } else {
            workUntil = nil
            restUntil = Self.restDeadline(now: now, startMinutes: startMinutes, endMinutes: endMinutes)
        }
        refresh(at: date)
    }

    var todayOverrideMenuTitle: String {
        if isManualRestActive { return "恢复自动安排" }
        if isManualWorkActive { return "恢复自动休息" }
        return isAutomaticRestDay ? "今天上班" : "今天休息"
    }

    var workdayStatusText: String {
        if isManualWorkActive { return chinaWorkdayKind.title + " · 已手动设为上班" }
        if isManualRestActive { return chinaWorkdayKind.title + " · 已手动设为休息" }
        return chinaWorkdayKind.title
    }

    var restStatusText: String {
        if isManualRestActive {
            return "手动休息至 " + (restResumeText ?? "计划恢复")
        }
        return chinaWorkdayKind.title
    }

    var restResumeText: String? {
        guard isRestingToday, let restUntil else { return nil }
        return restUntil.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func restDeadline(
        now: Date,
        startMinutes: Int,
        endMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        guard endMinutes <= startMinutes else {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
        }

        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let endDayOffset = currentMinutes < endMinutes ? 0 : 1
        let endDay = calendar.date(byAdding: .day, value: endDayOffset, to: today) ?? today
        return calendar.date(byAdding: .minute, value: endMinutes, to: endDay) ?? now
    }

    var snapshot: ScheduleSnapshot {
        Schedule.snapshot(now: now, startMinutes: startMinutes, endMinutes: endMinutes)
    }

    var isFloatingPanelActive: Bool {
        countdownEnabled && showFloatingPanel
    }

    var isMenuBarCountdownActive: Bool {
        countdownEnabled && showMenuBarRemaining
    }

    var cowMood: CowMood {
        if isRestingToday { return .resting }
        let state = snapshot
        switch state.phase {
        case .waiting: return .resting
        case .running: return state.remaining <= 5 * 60 ? .expectant : .focused
        case .finished: return .relaxed
        }
    }

    /// Keep the final second visible until the actual end time. Waiting for a
    /// schedule to start does not trigger the final-minute countdown.
    var finalMinuteSeconds: Int? {
        guard !isRestingToday else { return nil }
        let state = snapshot
        guard state.phase == .running,
              state.remaining > 0,
              state.remaining <= 60 else { return nil }
        return min(60, max(countdownSeconds(state.remaining), 1))
    }

    var startDate: Date {
        get { date(for: startMinutes) }
        set { startMinutes = minutes(for: newValue) }
    }

    var endDate: Date {
        get { date(for: endMinutes) }
        set { endMinutes = minutes(for: newValue) }
    }

    var backgroundSwiftUIColor: SwiftUI.Color { color(from: backgroundRGB) }
    var centerLabelSwiftUIColor: SwiftUI.Color { color(from: centerLabelRGB) }
    var waitingLabelSwiftUIColor: SwiftUI.Color { color(from: waitingLabelRGB) }
    var completedLabelSwiftUIColor: SwiftUI.Color { color(from: completedLabelRGB) }
    var accentSwiftUIColor: SwiftUI.Color { color(from: accentRGB) }
    var calendarAccentSwiftUIColor: SwiftUI.Color { color(from: calendarAccentRGB) }

    var effectivePanelSize: NSSize {
        CowLayout.panelSize(for: CGFloat(widgetSize), showsEars: showCowEars)
    }

    var coreHoverTime: String {
        let total = countdownSeconds(snapshot.remaining)
        if showCowEars { return String(format: "%02d", total % 60) }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return String(format: "%02d:%02d", hours, minutes) }
        return String(format: "%02d:%02d", minutes, total % 60)
    }

    var coreHoverHasTime: Bool {
        !isRestingToday && snapshot.phase != .finished
    }

    var earTime: (hours: String, minutes: String)? {
        guard !isRestingToday else { return nil }
        let state = snapshot
        if state.phase == .finished { return nil }
        // During the dedicated 60→1 core countdown, ear digits would mix
        // minute rounding with a standalone seconds value (and flicker between
        // 00 and 01 on hover). Keep the ear shapes, but let the core own time.
        if finalMinuteSeconds != nil { return nil }
        if state.phase == .waiting, !isCoreHovered {
            return (
                String(format: "%02d", startMinutes / 60),
                String(format: "%02d", startMinutes % 60)
            )
        }
        let remainingMinutes = isCoreHovered
            ? countdownSeconds(state.remaining) / 60
            : max(Int(ceil(state.remaining / 60)), 0)
        return (
            String(format: "%02d", remainingMinutes / 60),
            String(format: "%02d", remainingMinutes % 60)
        )
    }

    var statusText: String {
        statusText(at: now, showSeconds: showSeconds)
    }

    func statusText(at date: Date, showSeconds: Bool) -> String {
        if isResting(at: date) { return "休息" }
        let state = Schedule.snapshot(now: date, startMinutes: startMinutes, endMinutes: endMinutes)
        return switch state.phase {
        case .waiting: "距开始 \(format(state.remaining, showSeconds: showSeconds))"
        case .running: "剩余 \(format(state.remaining, showSeconds: showSeconds))"
        case .finished: "完成"
        }
    }

    var calendarStatusText: String {
        statusText(at: now, showSeconds: false)
    }

    private func isResting(at date: Date) -> Bool {
        if workUntil.map({ date < $0 }) ?? false { return false }
        if restUntil.map({ date < $0 }) ?? false { return true }
        let workDate = Schedule.workDate(
            for: date,
            startMinutes: startMinutes,
            endMinutes: endMinutes
        )
        return !ChinaWorkdayCalendar.kind(for: workDate).isWorkday
    }

    private func format(_ interval: TimeInterval, showSeconds: Bool) -> String {
        let total = countdownSeconds(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if showSeconds {
            return String(format: "%02d:%02d:%02d", hours, minutes, total % 60)
        }
        let roundedMinutes = max(Int(ceil(interval / 60)), 0)
        return String(format: "%02d小时%02d分", roundedMinutes / 60, roundedMinutes % 60)
    }

    func setCalendarPresented(_ presented: Bool) {
        guard isCalendarPresented != presented else { return }
        isCalendarPresented = presented
        scheduleNextRefresh()
    }

    func setSettingsPresented(_ presented: Bool) {
        guard isSettingsPresented != presented else { return }
        isSettingsPresented = presented
        scheduleNextRefresh()
    }

    var compactStatusText: String {
        compactStatusText(at: now, showSeconds: showSeconds)
    }

    func compactStatusText(at date: Date, showSeconds: Bool) -> String {
        if isResting(at: date) { return "休息" }
        let state = Schedule.snapshot(now: date, startMinutes: startMinutes, endMinutes: endMinutes)
        return switch state.phase {
        case .waiting: "\(formatCompact(state.remaining, showSeconds: showSeconds)) 后开始"
        case .running: formatCompact(state.remaining, showSeconds: showSeconds)
        case .finished: "完成"
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.settingsSchemaVersion: 0,
            Key.countdownEnabled: true,
            Key.startMinutes: DefaultValue.startMinutes,
            Key.endMinutes: DefaultValue.endMinutes,
            Key.widgetSize: DefaultValue.widgetSize,
            Key.showCowEars: true,
            Key.waitingLabel: DefaultValue.waitingLabel,
            Key.centerLabel: DefaultValue.centerLabel,
            Key.completedLabel: DefaultValue.completedLabel,
            Key.waitingLabelRGB: DefaultValue.waitingLabelRGB,
            Key.centerLabelRGB: DefaultValue.centerLabelRGB,
            Key.completedLabelRGB: DefaultValue.completedLabelRGB,
            Key.textColorVersion: 0,
            Key.showSeconds: true,
            Key.showFloatingPanel: true,
            Key.showMenuBarRemaining: true,
            Key.calendarFirstWeekday: 2,
            Key.showLunarDetails: true,
            Key.showWorkdayBadges: true,
            Key.showMonthSummary: true,
            Key.calendarAccentRGB: DefaultValue.calendarAccentRGB,
            Key.lockPanelPosition: false,
            Key.panelOpacity: DefaultValue.panelOpacity,
            Key.backgroundRGB: DefaultValue.backgroundRGB,
            Key.accentRGB: DefaultValue.accentRGB
        ])

        // Migrate old installs before validating the complete settings payload.
        defaults.removeObject(forKey: "useChinaWorkdays")
        if defaults.integer(forKey: Key.textColorVersion) < 1 {
            if defaults.integer(forKey: Key.centerLabelRGB) == 0x000000 {
                defaults.set(DefaultValue.centerLabelRGB, forKey: Key.centerLabelRGB)
            }
            if defaults.integer(forKey: Key.completedLabelRGB) == 0x000000 {
                defaults.set(DefaultValue.completedLabelRGB, forKey: Key.completedLabelRGB)
            }
            defaults.set(1, forKey: Key.textColorVersion)
        }

        let normalizedStart = Self.validMinutes(defaults.integer(forKey: Key.startMinutes), fallback: DefaultValue.startMinutes)
        let normalizedEnd = Self.validMinutes(defaults.integer(forKey: Key.endMinutes), fallback: DefaultValue.endMinutes)
        let normalizedSize = Self.clampedFinite(defaults.double(forKey: Key.widgetSize), range: 40...88, fallback: DefaultValue.widgetSize)
        let normalizedOpacity = Self.clampedFinite(defaults.double(forKey: Key.panelOpacity), range: 0.45...1, fallback: DefaultValue.panelOpacity)
        let normalizedWaitingLabel = Self.limitedLabel(defaults.string(forKey: Key.waitingLabel), fallback: DefaultValue.waitingLabel)
        let normalizedCenterLabel = Self.limitedLabel(defaults.string(forKey: Key.centerLabel), fallback: DefaultValue.centerLabel)
        let normalizedCompletedLabel = Self.limitedLabel(defaults.string(forKey: Key.completedLabel), fallback: DefaultValue.completedLabel)
        let normalizedWaitingRGB = Self.validRGB(defaults.integer(forKey: Key.waitingLabelRGB), fallback: DefaultValue.waitingLabelRGB)
        let normalizedCenterRGB = Self.validRGB(defaults.integer(forKey: Key.centerLabelRGB), fallback: DefaultValue.centerLabelRGB)
        let normalizedCompletedRGB = Self.validRGB(defaults.integer(forKey: Key.completedLabelRGB), fallback: DefaultValue.completedLabelRGB)
        let normalizedBackgroundRGB = Self.validRGB(defaults.integer(forKey: Key.backgroundRGB), fallback: DefaultValue.backgroundRGB)
        let normalizedAccentRGB = Self.validRGB(defaults.integer(forKey: Key.accentRGB), fallback: DefaultValue.accentRGB)
        let normalizedCalendarAccentRGB = Self.validRGB(
            defaults.integer(forKey: Key.calendarAccentRGB),
            fallback: DefaultValue.calendarAccentRGB
        )
        let normalizedFirstWeekday = defaults.integer(forKey: Key.calendarFirstWeekday) == 1 ? 1 : 2

        let normalizedValues: [(String, Any)] = [
            (Key.startMinutes, normalizedStart),
            (Key.endMinutes, normalizedEnd),
            (Key.widgetSize, normalizedSize),
            (Key.panelOpacity, normalizedOpacity),
            (Key.waitingLabel, normalizedWaitingLabel),
            (Key.centerLabel, normalizedCenterLabel),
            (Key.completedLabel, normalizedCompletedLabel),
            (Key.waitingLabelRGB, normalizedWaitingRGB),
            (Key.centerLabelRGB, normalizedCenterRGB),
            (Key.completedLabelRGB, normalizedCompletedRGB),
            (Key.backgroundRGB, normalizedBackgroundRGB),
            (Key.accentRGB, normalizedAccentRGB),
            (Key.calendarAccentRGB, normalizedCalendarAccentRGB),
            (Key.calendarFirstWeekday, normalizedFirstWeekday)
        ]
        normalizedValues.forEach { defaults.set($0.1, forKey: $0.0) }
        if defaults.integer(forKey: Key.settingsSchemaVersion) < Self.currentSettingsSchemaVersion {
            defaults.set(Self.currentSettingsSchemaVersion, forKey: Key.settingsSchemaVersion)
        }

        countdownEnabled = defaults.bool(forKey: Key.countdownEnabled)
        startMinutes = normalizedStart
        endMinutes = normalizedEnd
        widgetSize = normalizedSize
        showCowEars = defaults.bool(forKey: Key.showCowEars)
        waitingLabel = normalizedWaitingLabel
        centerLabel = normalizedCenterLabel
        completedLabel = normalizedCompletedLabel
        waitingLabelRGB = normalizedWaitingRGB
        centerLabelRGB = normalizedCenterRGB
        completedLabelRGB = normalizedCompletedRGB
        showSeconds = defaults.bool(forKey: Key.showSeconds)
        showFloatingPanel = defaults.bool(forKey: Key.showFloatingPanel)
        showMenuBarRemaining = defaults.bool(forKey: Key.showMenuBarRemaining)
        calendarFirstWeekday = normalizedFirstWeekday
        showLunarDetails = defaults.bool(forKey: Key.showLunarDetails)
        showWorkdayBadges = defaults.bool(forKey: Key.showWorkdayBadges)
        showMonthSummary = defaults.bool(forKey: Key.showMonthSummary)
        calendarAccentRGB = normalizedCalendarAccentRGB
        lockPanelPosition = defaults.bool(forKey: Key.lockPanelPosition)
        panelOpacity = normalizedOpacity
        backgroundRGB = normalizedBackgroundRGB
        accentRGB = normalizedAccentRGB
        let loginStatus = SMAppService.mainApp.status
        launchAtLoginEnabled = loginStatus == .enabled || loginStatus == .requiresApproval
        launchAtLoginNeedsApproval = loginStatus == .requiresApproval
        launchAtLoginError = nil
        restUntil = defaults.object(forKey: Key.restUntil) as? Date
        workUntil = defaults.object(forKey: Key.workUntil) as? Date
        if restUntil == nil,
           let legacyRestDay = defaults.object(forKey: Key.restDay) as? Date,
           Calendar.current.isDate(Date(), inSameDayAs: legacyRestDay) {
            restUntil = Self.restDeadline(
                now: legacyRestDay,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            )
        }
        defaults.removeObject(forKey: Key.restDay)
        scheduleNextRefresh()
    }

    private static func validMinutes(_ value: Int, fallback: Int) -> Int {
        (0..<(24 * 60)).contains(value) ? value : fallback
    }

    private static func clampedFinite(_ value: Double, range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func limitedLabel(_ value: String?, fallback: String) -> String {
        String((value ?? fallback).prefix(6))
    }

    private static func validRGB(_ value: Int, fallback: Int) -> Int {
        (0...0xFFFFFF).contains(value) ? value : fallback
    }

    func setBackgroundColor(_ color: SwiftUI.Color) {
        backgroundRGB = packedRGB(from: color)
    }

    func setCenterLabelColor(_ color: SwiftUI.Color) {
        centerLabelRGB = packedRGB(from: color)
    }

    func setWaitingLabelColor(_ color: SwiftUI.Color) {
        waitingLabelRGB = packedRGB(from: color)
    }

    func setCompletedLabelColor(_ color: SwiftUI.Color) {
        completedLabelRGB = packedRGB(from: color)
    }

    func setAccentColor(_ color: SwiftUI.Color) {
        accentRGB = packedRGB(from: color)
    }

    func setCalendarAccentColor(_ color: SwiftUI.Color) {
        calendarAccentRGB = packedRGB(from: color)
    }

    func resetAppearanceDefaults() {
        widgetSize = DefaultValue.widgetSize
        panelOpacity = DefaultValue.panelOpacity
        backgroundRGB = DefaultValue.backgroundRGB
        accentRGB = DefaultValue.accentRGB
    }

    func resetTextDefaults() {
        waitingLabel = DefaultValue.waitingLabel
        centerLabel = DefaultValue.centerLabel
        completedLabel = DefaultValue.completedLabel
        waitingLabelRGB = DefaultValue.waitingLabelRGB
        centerLabelRGB = DefaultValue.centerLabelRGB
        completedLabelRGB = DefaultValue.completedLabelRGB
    }

    func resetCalendarDisplayDefaults() {
        calendarFirstWeekday = 2
        showLunarDetails = true
        showWorkdayBadges = true
        showMonthSummary = true
        calendarAccentRGB = DefaultValue.calendarAccentRGB
    }

    private func packedRGB(from color: SwiftUI.Color) -> Int {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return 0 }
        let red = Int((converted.redComponent * 255).rounded())
        let green = Int((converted.greenComponent * 255).rounded())
        let blue = Int((converted.blueComponent * 255).rounded())
        return (red << 16) | (green << 8) | blue
    }

    private func color(from rgb: Int) -> SwiftUI.Color {
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        return SwiftUI.Color(red: red, green: green, blue: blue)
    }

    func refresh() {
        refresh(at: Date())
    }

    /// Refreshing at an explicit instant keeps wake/clock recovery testable and
    /// clears an expired rest marker instead of persisting stale state forever.
    func refresh(at date: Date) {
        now = date
        if let restUntil, date >= restUntil {
            self.restUntil = nil
        }
        if let workUntil, date >= workUntil {
            self.workUntil = nil
        }
        scheduleNextRefresh()
    }

    /// A manual clock or time-zone change can move the intended local end of a
    /// rest period. Re-anchor it without adding a polling timer.
    func resynchronizeAfterSystemTimeChange(at date: Date = Date()) {
        let restIsStillActive = restUntil.map { date < $0 } ?? false
        let workIsStillActive = workUntil.map { date < $0 } ?? false
        now = date
        if restIsStillActive {
            restUntil = Self.restDeadline(
                now: date,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            )
        } else if restUntil != nil {
            restUntil = nil
        }
        if workIsStillActive {
            workUntil = Self.restDeadline(
                now: date,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            )
        } else if workUntil != nil {
            workUntil = nil
        }
        scheduleNextRefresh()
    }

    func setCoreHovered(_ hovered: Bool) {
        guard isCoreHovered != hovered else { return }
        isCoreHovered = hovered
        refresh()
    }

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled || status == .requiresApproval
        launchAtLoginNeedsApproval = status == .requiresApproval
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginError = nil
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func formatCompact(_ interval: TimeInterval, showSeconds: Bool) -> String {
        let total = countdownSeconds(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if showSeconds {
            return String(format: "%02d:%02d:%02d", hours, minutes, total % 60)
        }
        let roundedMinutes = max(Int(ceil(interval / 60)), 0)
        return String(format: "%02d:%02d", roundedMinutes / 60, roundedMinutes % 60)
    }

    private func scheduleNextRefresh() {
        timer?.invalidate()
        timer = nil

        guard countdownEnabled,
              isFloatingPanelActive || isMenuBarCountdownActive || isCalendarPresented || isSettingsPresented else {
            return
        }

        let delay = nextRefreshDelay
        let nextTimer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        nextTimer.tolerance = delay <= 1.1 ? 0.08 : min(delay * 0.02, 0.20)
        RunLoop.main.add(nextTimer, forMode: .common)
        timer = nextTimer
    }

    private var nextRefreshDelay: TimeInterval {
        let state = snapshot
        let planTransition = Schedule.nextTransition(
            after: now,
            startMinutes: startMinutes,
            endMinutes: endMinutes
        )

        if isRestingToday {
            let nextMidnight = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Calendar.current.startOfDay(for: now)
            ) ?? now.addingTimeInterval(86_400)
            var restDelays = [
                planTransition.timeIntervalSince(now),
                nextMidnight.timeIntervalSince(now)
            ]
            if let restUntil { restDelays.append(restUntil.timeIntervalSince(now)) }
            return max(restDelays.filter { $0 > 0 }.min() ?? 3600, 0.05)
        }

        let secondPrecision = (isCoreHovered && coreHoverHasTime)
            || (showFloatingPanel && finalMinuteSeconds != nil)
            || (isMenuBarCountdownActive && showSeconds)

        if secondPrecision {
            let fraction = now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1)
            return max(1.015 - fraction, 0.05)
        }

        var delays = [
            planTransition.timeIntervalSince(now)
        ]
        if let workUntil, workUntil > now {
            delays.append(workUntil.timeIntervalSince(now))
        }

        if state.phase == .running {
            if state.remaining > 5 * 60 { delays.append(state.remaining - 5 * 60) }
            if showFloatingPanel, state.remaining > 60 { delays.append(state.remaining - 60) }
        }

        let needsMinuteUpdates = (showFloatingPanel && showCowEars)
            || isMenuBarCountdownActive
            || isCalendarPresented
        if needsMinuteUpdates, state.remaining > 0 {
            let remainder = state.remaining.truncatingRemainder(dividingBy: 60)
            delays.append(remainder > 0.05 ? remainder : 60)
        }

        return max(delays.filter { $0 > 0 }.min() ?? 3600, 0.05)
    }

    private func date(for minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: now)) ?? now
    }

    private func minutes(for date: Date) -> Int {
        let values = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (values.hour ?? 0) * 60 + (values.minute ?? 0)
    }

    /// Countdown displays keep the final partial second visible. Keeping this
    /// conversion in one place prevents the menu bar and floating cow from
    /// disagreeing around second boundaries.
    private func countdownSeconds(_ interval: TimeInterval) -> Int {
        max(Int(ceil(interval)), 0)
    }

}
