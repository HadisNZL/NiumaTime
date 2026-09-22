import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ProgressModel: ObservableObject {
    private enum Key {
        static let startMinutes = "startMinutes"
        static let endMinutes = "endMinutes"
        static let circleSize = "circleSize"
        static let centerLabel = "centerLabel"
        static let completedLabel = "completedLabel"
        static let centerLabelRGB = "centerLabelRGB"
        static let completedLabelRGB = "completedLabelRGB"
        static let textColorVersion = "textColorVersion"
        static let showSeconds = "showSeconds"
        static let showFloatingPanel = "showFloatingPanel"
        static let showMenuBarRemaining = "showMenuBarRemaining"
        static let panelOpacity = "panelOpacity"
        static let backgroundRGB = "backgroundRGB"
        static let backgroundOpacity = "backgroundOpacity"
        static let progressRGB = "progressRGB"
        static let progressOpacity = "progressOpacity"
        static let trackRGB = "trackRGB"
        static let trackOpacity = "trackOpacity"
        static let beaconRGB = "beaconRGB"
        static let beaconDiameter = "beaconDiameter"
        static let beaconSizeVersion = "beaconSizeVersion"
    }

    private let defaults: UserDefaults
    private var timer: Timer?

    @Published var now = Date()
    @Published var startMinutes: Int { didSet { defaults.set(startMinutes, forKey: Key.startMinutes); refresh() } }
    @Published var endMinutes: Int { didSet { defaults.set(endMinutes, forKey: Key.endMinutes); refresh() } }
    @Published var circleSize: Double { didSet { defaults.set(circleSize, forKey: Key.circleSize) } }
    @Published var centerLabel: String { didSet { defaults.set(centerLabel, forKey: Key.centerLabel) } }
    @Published var completedLabel: String { didSet { defaults.set(completedLabel, forKey: Key.completedLabel) } }
    @Published var centerLabelRGB: Int { didSet { defaults.set(centerLabelRGB, forKey: Key.centerLabelRGB) } }
    @Published var completedLabelRGB: Int { didSet { defaults.set(completedLabelRGB, forKey: Key.completedLabelRGB) } }
    @Published var showSeconds: Bool { didSet { defaults.set(showSeconds, forKey: Key.showSeconds) } }
    @Published var showFloatingPanel: Bool { didSet { defaults.set(showFloatingPanel, forKey: Key.showFloatingPanel) } }
    @Published var showMenuBarRemaining: Bool { didSet { defaults.set(showMenuBarRemaining, forKey: Key.showMenuBarRemaining) } }
    @Published var panelOpacity: Double { didSet { defaults.set(panelOpacity, forKey: Key.panelOpacity) } }
    @Published var backgroundRGB: Int { didSet { defaults.set(backgroundRGB, forKey: Key.backgroundRGB) } }
    @Published var backgroundOpacity: Double { didSet { defaults.set(backgroundOpacity, forKey: Key.backgroundOpacity) } }
    @Published var progressRGB: Int { didSet { defaults.set(progressRGB, forKey: Key.progressRGB) } }
    @Published var progressOpacity: Double { didSet { defaults.set(progressOpacity, forKey: Key.progressOpacity) } }
    @Published var trackRGB: Int { didSet { defaults.set(trackRGB, forKey: Key.trackRGB) } }
    @Published var trackOpacity: Double { didSet { defaults.set(trackOpacity, forKey: Key.trackOpacity) } }
    @Published var beaconRGB: Int { didSet { defaults.set(beaconRGB, forKey: Key.beaconRGB) } }
    @Published var beaconDiameter: Double { didSet { defaults.set(beaconDiameter, forKey: Key.beaconDiameter) } }

    var snapshot: ScheduleSnapshot {
        Schedule.snapshot(now: now, startMinutes: startMinutes, endMinutes: endMinutes)
    }

    /// Keep the final second visible until the actual end time. Waiting for a
    /// schedule to start does not trigger the final-minute countdown.
    var finalMinuteSeconds: Int? {
        let state = snapshot
        guard state.phase == .running,
              state.remaining > 0,
              state.remaining <= 60 else { return nil }
        return min(60, max(Int(ceil(state.remaining)), 1))
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
    var completedLabelSwiftUIColor: SwiftUI.Color { color(from: completedLabelRGB) }
    var progressSwiftUIColor: SwiftUI.Color { color(from: progressRGB) }
    var trackSwiftUIColor: SwiftUI.Color { color(from: trackRGB) }
    var beaconSwiftUIColor: SwiftUI.Color { color(from: beaconRGB) }

    /// The visual orbit keeps its configured diameter. The transparent window
    /// grows only when a large beacon would otherwise extend beyond its bounds.
    var effectiveWidgetSize: Double {
        let orbitInset = max(circleSize * 0.11, 4)
        let overflow = max(beaconDiameter / 2 - orbitInset + 1, 0)
        return circleSize + overflow * 2
    }

    var backgroundTextColor: SwiftUI.Color {
        let red = Double((backgroundRGB >> 16) & 0xFF) / 255
        let green = Double((backgroundRGB >> 8) & 0xFF) / 255
        let blue = Double(backgroundRGB & 0xFF) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.56 ? .black : .white
    }

    var statusText: String {
        switch snapshot.phase {
        case .waiting: "距开始 \(format(snapshot.remaining))"
        case .running: "剩余 \(format(snapshot.remaining))"
        case .finished: "今日完成"
        }
    }

    var compactStatusText: String {
        switch snapshot.phase {
        case .waiting: "\(formatCompact(snapshot.remaining)) 后开始"
        case .running: formatCompact(snapshot.remaining)
        case .finished: "完成"
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.startMinutes: 9 * 60,
            Key.endMinutes: 18 * 60,
            Key.circleSize: 56.0,
            Key.centerLabel: "牛马",
            Key.completedLabel: "下班",
            Key.centerLabelRGB: 0x4338CA,
            Key.completedLabelRGB: 0x059669,
            Key.textColorVersion: 0,
            Key.showSeconds: true,
            Key.showFloatingPanel: true,
            Key.showMenuBarRemaining: true,
            Key.panelOpacity: 0.90,
            Key.backgroundRGB: 0xE9ECF5,
            Key.backgroundOpacity: 0.92,
            Key.progressRGB: 0x5856D6,
            Key.progressOpacity: 1.0,
            Key.trackRGB: 0x6B7280,
            Key.trackOpacity: 0.30,
            Key.beaconRGB: 0x5856D6,
            Key.beaconDiameter: 8.0,
            Key.beaconSizeVersion: 0
        ])
        startMinutes = defaults.integer(forKey: Key.startMinutes)
        endMinutes = defaults.integer(forKey: Key.endMinutes)
        circleSize = defaults.double(forKey: Key.circleSize)
        centerLabel = defaults.string(forKey: Key.centerLabel) ?? "牛马"
        completedLabel = defaults.string(forKey: Key.completedLabel) ?? "下班"
        centerLabelRGB = defaults.integer(forKey: Key.centerLabelRGB)
        completedLabelRGB = defaults.integer(forKey: Key.completedLabelRGB)
        showSeconds = defaults.bool(forKey: Key.showSeconds)
        showFloatingPanel = defaults.bool(forKey: Key.showFloatingPanel)
        showMenuBarRemaining = defaults.bool(forKey: Key.showMenuBarRemaining)
        panelOpacity = defaults.double(forKey: Key.panelOpacity)
        backgroundRGB = defaults.integer(forKey: Key.backgroundRGB)
        backgroundOpacity = defaults.double(forKey: Key.backgroundOpacity)
        progressRGB = defaults.integer(forKey: Key.progressRGB)
        progressOpacity = defaults.double(forKey: Key.progressOpacity)
        trackRGB = defaults.integer(forKey: Key.trackRGB)
        trackOpacity = defaults.double(forKey: Key.trackOpacity)
        beaconRGB = defaults.integer(forKey: Key.beaconRGB)
        beaconDiameter = defaults.double(forKey: Key.beaconDiameter)
        if defaults.integer(forKey: Key.textColorVersion) < 1 {
            if centerLabelRGB == 0x000000 { centerLabelRGB = 0x4338CA }
            if completedLabelRGB == 0x000000 { completedLabelRGB = 0x059669 }
            defaults.set(1, forKey: Key.textColorVersion)
        }
        if defaults.integer(forKey: Key.beaconSizeVersion) < 1 {
            if beaconDiameter == 6 { beaconDiameter = 8 }
            defaults.set(1, forKey: Key.beaconSizeVersion)
        }
        startTimer()
    }

    func setBackgroundColor(_ color: SwiftUI.Color) {
        backgroundRGB = packedRGB(from: color)
    }

    func setCenterLabelColor(_ color: SwiftUI.Color) {
        centerLabelRGB = packedRGB(from: color)
    }

    func setCompletedLabelColor(_ color: SwiftUI.Color) {
        completedLabelRGB = packedRGB(from: color)
    }

    func setProgressColor(_ color: SwiftUI.Color) {
        progressRGB = packedRGB(from: color)
    }

    func setTrackColor(_ color: SwiftUI.Color) {
        trackRGB = packedRGB(from: color)
    }

    func setBeaconColor(_ color: SwiftUI.Color) {
        beaconRGB = packedRGB(from: color)
    }

    func resetAppearanceDefaults() {
        circleSize = 56
        panelOpacity = 0.90
        backgroundRGB = 0xE9ECF5
        backgroundOpacity = 0.92
        centerLabelRGB = 0x4338CA
        completedLabelRGB = 0x059669
        progressRGB = 0x5856D6
        progressOpacity = 1.0
        trackRGB = 0x6B7280
        trackOpacity = 0.30
        beaconRGB = 0x5856D6
        beaconDiameter = 8.0
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
        now = Date()
    }

    func format(_ interval: TimeInterval) -> String {
        let total = max(Int(interval.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if showSeconds {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        let roundedMinutes = max(Int(ceil(interval / 60)), 0)
        return String(format: "%02d小时%02d分", roundedMinutes / 60, roundedMinutes % 60)
    }

    private func formatCompact(_ interval: TimeInterval) -> String {
        let total = max(Int(interval.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if showSeconds {
            return String(format: "%02d:%02d:%02d", hours, minutes, total % 60)
        }
        let roundedMinutes = max(Int(ceil(interval / 60)), 0)
        return String(format: "%02d:%02d", roundedMinutes / 60, roundedMinutes % 60)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 0.12
    }

    private func date(for minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: now)) ?? now
    }

    private func minutes(for date: Date) -> Int {
        let values = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (values.hour ?? 0) * 60 + (values.minute ?? 0)
    }
}
