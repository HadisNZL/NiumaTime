import AppKit
import Combine
import SwiftUI

enum AppVersion {
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    static var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static var value: String {
        guard let build, build != short else { return short }
        return "\(short)（\(build)）"
    }

    static var displayText: String { "版本 \(value)" }
}

enum AccessibilityAppearance {
    static func panelOpacity(userOpacity: Double, reduceTransparency: Bool) -> Double {
        reduceTransparency ? 1 : userOpacity
    }
}

@main
struct FloatProgressApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = ProgressModel()
    private var statusItem: NSStatusItem!
    private var restMenuItem: NSMenuItem!
    private var lockPositionMenuItem: NSMenuItem!
    private var panel: NSPanel!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePanel()
        observeModel()
        observeSystemTimeChanges()
        updateStatusItem()
        if model.showFloatingPanel { panel.orderFrontRegardless() }
    }

    private func observeSystemTimeChanges() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(systemClockDidChange), name: .NSSystemClockDidChange, object: nil)
        center.addObserver(self, selector: #selector(systemClockDidChange), name: .NSSystemTimeZoneDidChange, object: nil)
        center.addObserver(self, selector: #selector(calendarDayDidChange), name: .NSCalendarDayChanged, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = StatusBarCowIcon.image
            button.imagePosition = .imageLeading
            button.font = StatusBarCowIcon.countdownFont
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "显示并找回牛马", action: #selector(revealPanel), keyEquivalent: "r")
        menu.addItem(withTitle: "隐藏牛马", action: #selector(hidePanel), keyEquivalent: "p")
        lockPositionMenuItem = menu.addItem(withTitle: "锁定位置", action: #selector(toggleLockPanelPosition), keyEquivalent: "")
        restMenuItem = menu.addItem(withTitle: "今天休息", action: #selector(toggleRestToday), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "关于牛马", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出牛马", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func configurePanel() {
        let size = model.effectivePanelSize
        let content = FloatingProgressView(
            model: model,
            openSettings: { [weak self] in self?.openSettings() }
        )

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: content)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = !model.lockPanelPosition
        panel.alphaValue = effectivePanelOpacity
        panel.setFrameAutosaveName("WorkhorseCirclePanel")

        if !panel.setFrameUsingName("WorkhorseCirclePanel") {
            positionPanelAtTopRight()
        }
        resizePanel(to: size, preserveCenter: true)
        ensurePanelIsVisible()
    }

    private func observeModel() {
        model.$now
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        model.$showMenuBarRemaining
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        model.$showSeconds
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        model.$restUntil
            .dropFirst()
            .sink { [weak self] _ in
                // @Published notifies before restUntil changes; update on the next main-loop turn.
                DispatchQueue.main.async { self?.updateStatusItem() }
            }
            .store(in: &cancellables)
        model.$showFloatingPanel
            .sink { [weak self] visible in
                guard let self, self.panel != nil else { return }
                if visible {
                    self.ensurePanelIsVisible()
                    self.panel.orderFrontRegardless()
                } else {
                    self.panel.orderOut(nil)
                }
            }
            .store(in: &cancellables)
        Publishers.CombineLatest(model.$widgetSize, model.$showCowEars)
            .dropFirst()
            .sink { [weak self] widgetSize, showCowEars in
                guard let self else { return }
                // @Published emits incoming values before stored properties change.
                self.resizePanel(to: CowLayout.panelSize(for: CGFloat(widgetSize), showsEars: showCowEars), preserveCenter: true)
            }
            .store(in: &cancellables)
        model.$panelOpacity
            .sink { [weak self] _ in self?.applyEffectivePanelOpacity() }
            .store(in: &cancellables)
        model.$lockPanelPosition
            .sink { [weak self] locked in
                self?.panel?.isMovableByWindowBackground = !locked
                self?.lockPositionMenuItem?.title = locked ? "解锁位置" : "锁定位置"
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = model.showMenuBarRemaining ? " \(model.compactStatusText)" : ""
        button.toolTip = model.isRestingToday
            ? "牛马 · 休息至 \(model.restResumeText ?? "计划恢复")"
            : "牛马 · \(formattedTime(model.startMinutes))–\(formattedTime(model.endMinutes)) · \(model.statusText)"
        restMenuItem.title = model.isRestingToday ? "恢复倒计时" : "今天休息"
    }

    private func resizePanel(to size: NSSize, preserveCenter: Bool) {
        guard panel != nil else { return }
        var frame = panel.frame
        if preserveCenter {
            frame.origin.x += (frame.width - size.width) / 2
            frame.origin.y += (frame.height - size.height) / 2
        }
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
        ensurePanelIsVisible()
    }

    private func positionPanelAtTopRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = model.effectivePanelSize
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24))
    }

    private func ensurePanelIsVisible(forceReposition: Bool = false) {
        guard panel != nil else { return }
        let frame = panel.frame
        let mostlyVisible = NSScreen.screens.contains { screen in
            let intersection = screen.visibleFrame.intersection(frame)
            return intersection.width >= frame.width * 0.75 && intersection.height >= frame.height * 0.75
        }
        if forceReposition || !mostlyVisible { positionPanelAtTopRight() }
    }

    private func formattedTime(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    @objc private func revealPanel() {
        model.showFloatingPanel = true
        ensurePanelIsVisible(forceReposition: true)
        panel.orderFrontRegardless()
    }

    @objc private func hidePanel() {
        model.showFloatingPanel = false
    }

    @objc private func toggleRestToday() {
        model.toggleRestToday()
        updateStatusItem()
    }

    @objc private func toggleLockPanelPosition() {
        model.lockPanelPosition.toggle()
    }

    @objc private func systemClockDidChange(_ notification: Notification) {
        model.resynchronizeAfterSystemTimeChange()
    }

    @objc private func calendarDayDidChange(_ notification: Notification) {
        model.refresh()
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        model.refresh()
        ensurePanelIsVisible()
    }

    @objc private func accessibilityDisplayOptionsDidChange(_ notification: Notification) {
        applyEffectivePanelOpacity()
    }

    private var effectivePanelOpacity: Double {
        AccessibilityAppearance.panelOpacity(
            userOpacity: model.panelOpacity,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )
    }

    private func applyEffectivePanelOpacity() {
        panel?.alphaValue = effectivePanelOpacity
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                model: model,
                showFloatingPanel: { [weak self] in
                    self?.model.showFloatingPanel = true
                    self?.panel.orderFrontRegardless()
                },
                quit: { NSApplication.shared.terminate(nil) }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "牛马设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "牛马",
            .applicationVersion: AppVersion.value,
            .credits: NSAttributedString(string: "轻量、原生的牛形时间进度组件")
        ])
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === settingsWindow else { return }
        settingsWindow = nil
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        ensurePanelIsVisible()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        ensurePanelIsVisible()
        model.refresh()
        model.refreshLaunchAtLoginStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

}
