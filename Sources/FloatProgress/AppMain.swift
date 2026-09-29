import AppKit
import Carbon.HIToolbox
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

enum CalendarPopoverPlacement {
    // Keep the popover window just outside the menu-bar window. Its shadow and
    // arrow still meet the bar visually, while its hit area cannot cover the
    // status icon when the countdown title is hidden.
    static let windowTopGap: CGFloat = 1

    static func aligningTopEdge(of frame: NSRect, toMenuBarBottom menuBarBottom: CGFloat) -> NSRect {
        var aligned = frame
        aligned.origin.y = menuBarBottom - windowTopGap - frame.height
        return aligned
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private let model = ProgressModel()
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var calendarPopover: NSPopover?
    private var calendarPresentationPending = false
    private var calendarLocalMouseMonitor: Any?
    private var calendarGlobalMouseMonitor: Any?
    private var statusIconDayKey: Int?
    private var hotKeyHandler: EventHandlerRef?
    private var calendarHotKey: EventHotKeyRef?
    private var floatingPanelHotKey: EventHotKeyRef?
    private var restMenuItem: NSMenuItem!
    private var countdownMasterMenuItem: NSMenuItem!
    private var menuBarCountdownMenuItem: NSMenuItem!
    private var floatingPanelMenuItem: NSMenuItem!
    private var cowEarsMenuItem: NSMenuItem!
    private var lockPositionMenuItem: NSMenuItem!
    private var panel: NSPanel!
    private var floatingPanelContentInstalled = false
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePanel()
        observeModel()
        observeSystemTimeChanges()
        configureGlobalHotKeys()
        updateStatusItem()
        if model.isFloatingPanelActive { panel.orderFrontRegardless() }

        // A first launch can resume after Gatekeeper's confirmation while the
        // app is still transitioning from its stopped launch state. Restore on
        // the next main-loop turn so a single click is enough to show both UI
        // surfaces without adding a timer or keeping extra objects alive.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.restorePresentationAfterSystemEvent()
        }
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
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
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
            // The open popover freezes the containing item width, so the
            // familiar icon-first order can keep a stable leading anchor.
            button.imagePosition = .imageLeading
            button.alignment = .left
            button.font = StatusBarCalendarIcon.countdownFont
            button.target = self
            button.action = #selector(statusItemPressed)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        let openCalendarMenuItem = menu.addItem(
            withTitle: "打开牛马日历",
            action: #selector(openCalendar),
            keyEquivalent: "j"
        )
        openCalendarMenuItem.keyEquivalentModifierMask = [.option, .shift]
        menu.addItem(.separator())
        countdownMasterMenuItem = menu.addItem(
            withTitle: model.countdownEnabled ? "一键关闭牛马倒计时" : "一键开启牛马倒计时",
            action: #selector(toggleCountdownEnabled),
            keyEquivalent: ""
        )
        menuBarCountdownMenuItem = menu.addItem(
            withTitle: model.showMenuBarRemaining ? "隐藏菜单栏倒计时" : "显示菜单栏倒计时",
            action: #selector(toggleMenuBarCountdown),
            keyEquivalent: ""
        )
        menuBarCountdownMenuItem.indentationLevel = 1
        floatingPanelMenuItem = menu.addItem(
            withTitle: model.showFloatingPanel ? "隐藏牛马悬浮" : "显示牛马悬浮",
            action: #selector(toggleFloatingPanelVisibility),
            keyEquivalent: "l"
        )
        floatingPanelMenuItem.keyEquivalentModifierMask = [.option, .shift]
        floatingPanelMenuItem.indentationLevel = 1
        cowEarsMenuItem = menu.addItem(
            withTitle: model.showCowEars ? "隐藏牛耳朵" : "显示牛耳朵",
            action: #selector(toggleCowEars),
            keyEquivalent: ""
        )
        cowEarsMenuItem.indentationLevel = 1
        cowEarsMenuItem.isHidden = !model.countdownEnabled || !model.showFloatingPanel
        lockPositionMenuItem = menu.addItem(
            withTitle: "锁定牛马悬浮位置",
            action: #selector(toggleLockPanelPosition),
            keyEquivalent: ""
        )
        lockPositionMenuItem.indentationLevel = 1
        restMenuItem = menu.addItem(withTitle: "今天休息", action: #selector(toggleRestToday), keyEquivalent: "")
        restMenuItem.indentationLevel = 1
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "关于牛马日历", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出牛马日历", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusMenu = menu
        updateCountdownMenuAvailability(model.countdownEnabled)
    }

    private func configurePanel() {
        let size = model.effectivePanelSize
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Keep the window and its saved position, but only retain the SwiftUI
        // tree while the floating cow is actually visible.
        panel.contentView = nil
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = !model.lockPanelPosition
        panel.alphaValue = effectivePanelOpacity
        panel.setFrameAutosaveName("WorkhorseCirclePanel")

        if model.isFloatingPanelActive {
            installFloatingPanelContentIfNeeded()
        }

        if !panel.setFrameUsingName("WorkhorseCirclePanel") {
            positionPanelAtTopRight()
        }
        resizePanel(to: size, preserveCenter: true)
        ensurePanelIsVisible()
    }

    private func observeModel() {
        model.$countdownEnabled
            .sink { [weak self] enabled in
                self?.applyCountdownEnabledState(enabled)
            }
            .store(in: &cancellables)
        model.$now
            .sink { [weak self] date in self?.updateStatusItem(at: date) }
            .store(in: &cancellables)
        model.$showMenuBarRemaining
            .sink { [weak self] value in
                self?.menuBarCountdownMenuItem?.title = value ? "隐藏菜单栏倒计时" : "显示菜单栏倒计时"
                self?.updateStatusItem(showMenuBarRemaining: value)
            }
            .store(in: &cancellables)
        model.$showSeconds
            .sink { [weak self] value in
                self?.updateStatusItem(showSeconds: value)
            }
            .store(in: &cancellables)
        Publishers.Merge(
            model.$restUntil.dropFirst().map { _ in () },
            model.$workUntil.dropFirst().map { _ in () }
        )
            .sink { [weak self] _ in
                // @Published notifies before stored properties change.
                DispatchQueue.main.async { self?.updateStatusItem() }
            }
            .store(in: &cancellables)
        model.$showFloatingPanel
            .sink { [weak self] visible in
                guard let self, self.panel != nil else { return }
                self.floatingPanelMenuItem?.title = visible ? "隐藏牛马悬浮" : "显示牛马悬浮"
                self.cowEarsMenuItem?.isHidden = !self.model.countdownEnabled || !visible
                if self.model.countdownEnabled && visible {
                    self.installFloatingPanelContentIfNeeded()
                    self.ensurePanelIsVisible()
                    self.panel.orderFrontRegardless()
                } else {
                    self.panel.orderOut(nil)
                    self.releaseFloatingPanelContent()
                }
            }
            .store(in: &cancellables)
        Publishers.CombineLatest(model.$widgetSize, model.$showCowEars)
            .dropFirst()
            .sink { [weak self] widgetSize, showCowEars in
                guard let self else { return }
                // @Published emits incoming values before stored properties change.
                self.cowEarsMenuItem?.title = showCowEars ? "隐藏牛耳朵" : "显示牛耳朵"
                self.resizePanel(to: CowLayout.panelSize(for: CGFloat(widgetSize), showsEars: showCowEars), preserveCenter: true)
            }
            .store(in: &cancellables)
        model.$panelOpacity
            .sink { [weak self] _ in self?.applyEffectivePanelOpacity() }
            .store(in: &cancellables)
        model.$lockPanelPosition
            .sink { [weak self] locked in
                self?.panel?.isMovableByWindowBackground = !locked
                self?.lockPositionMenuItem?.title = locked ? "解锁牛马悬浮位置" : "锁定牛马悬浮位置"
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(
        at date: Date = Date(),
        countdownEnabled: Bool? = nil,
        showMenuBarRemaining: Bool? = nil,
        showSeconds: Bool? = nil
    ) {
        guard let button = statusItem.button else { return }
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let iconDayKey = (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
        if statusIconDayKey != iconDayKey {
            button.image = StatusBarCalendarIcon.image(for: date)
            statusIconDayKey = iconDayKey
        }
        let isCountdownEnabled = countdownEnabled ?? model.countdownEnabled
        let shouldShowRemaining = isCountdownEnabled && (showMenuBarRemaining ?? model.showMenuBarRemaining)
        let shouldShowSeconds = showSeconds ?? model.showSeconds
        if statusItem.length != NSStatusItem.variableLength {
            statusItem.length = NSStatusItem.variableLength
        }
        let previousTitleWidth = statusTitleWidth(button.title)
        let nextTitle = shouldShowRemaining
            ? " \(model.compactStatusText(at: date, showSeconds: shouldShowSeconds))"
            : ""
        button.title = nextTitle
        if abs(previousTitleWidth - statusTitleWidth(nextTitle)) > 0.5 {
            realignOpenCalendarPopover(afterLayoutOf: button)
        }
        if isCountdownEnabled {
            let currentStatus = model.statusText(at: date, showSeconds: shouldShowSeconds)
            button.toolTip = currentStatus == "休息"
                ? "牛马日历 · \(model.restStatusText)"
                : "牛马日历 · \(formattedTime(model.startMinutes))–\(formattedTime(model.endMinutes)) · \(currentStatus)"
        } else {
            button.toolTip = "牛马日历"
        }
        restMenuItem.title = model.todayOverrideMenuTitle
    }

    private func statusTitleWidth(_ title: String) -> CGFloat {
        (title as NSString).size(withAttributes: [.font: StatusBarCalendarIcon.countdownFont]).width
    }

    private func realignOpenCalendarPopover(afterLayoutOf button: NSStatusBarButton) {
        guard calendarPopover?.isShown == true else { return }
        DispatchQueue.main.async { [weak self, weak button] in
            guard let self,
                  let button,
                  let popover = self.calendarPopover,
                  popover.isShown else { return }
            button.superview?.layoutSubtreeIfNeeded()
            popover.positioningRect = self.statusIconAnchorRect(in: button)
            // Updating the positioning rect lets AppKit choose the horizontal
            // arrow position. Re-apply only the fixed vertical edge afterward.
            DispatchQueue.main.async { [weak self] in
                self?.alignOpenCalendarPopoverTopEdge()
            }
        }
    }

    @objc private func statusItemPressed() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            model.refresh()
            updateStatusItem()
            dismissCalendarPopover()
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleCalendarPopover()
        }
    }

    @objc private func openCalendar() {
        showCalendarPopover()
    }

    private func toggleCalendarPopover() {
        if calendarPresentationPending {
            calendarPresentationPending = false
        } else if calendarPopover?.isShown == true {
            dismissCalendarPopover()
        } else {
            showCalendarPopover()
        }
    }

    private func showCalendarPopover() {
        guard calendarPopover?.isShown != true else { return }
        calendarPresentationPending = true
        NSApp.activate(ignoringOtherApps: true)

        // A status-item menu can finish tracking after its action returns.
        // Present on the next main-loop turn so the first left click after a
        // right-click command always opens the calendar instead of only
        // reactivating the accessory app.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.calendarPresentationPending,
                  self.calendarPopover?.isShown != true else { return }
            self.calendarPresentationPending = false
            self.presentCalendarPopover()
        }
    }

    private func presentCalendarPopover() {
        guard let button = statusItem.button else { return }
        if calendarPopover?.isShown == true { return }
        model.refresh()

        let popover = NSPopover()
        // Outside clicks are handled by our local/global monitors below.
        // Using .transient as well creates two competing close paths: with the
        // countdown master disabled, AppKit can close on mouse-down and the
        // status button then reopens on mouse-up, making the second click look
        // ineffective. Keep a single owner for dismissal instead.
        popover.behavior = .applicationDefined
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.delegate = self
        popover.contentSize = NSSize(width: 410, height: 550)
        popover.contentViewController = NSHostingController(
            rootView: CalendarPopoverView(model: model)
        )
        calendarPopover = popover
        popover.show(
            relativeTo: statusIconAnchorRect(in: button),
            of: button,
            preferredEdge: .minY
        )
        alignOpenCalendarPopoverTopEdge()
        DispatchQueue.main.async { [weak self] in
            // NSPopover performs a final layout pass after show(). Correct the
            // top edge once more without changing its horizontal position.
            self?.alignOpenCalendarPopoverTopEdge()
        }
        model.setCalendarPresented(true)
        popover.contentViewController?.view.window?.makeKey()
        installCalendarDismissMonitors()
    }

    private func alignOpenCalendarPopoverTopEdge() {
        guard calendarPopover?.isShown == true,
              let menuBarWindow = statusItem.button?.window,
              let popoverWindow = calendarPopover?.contentViewController?.view.window else { return }
        let alignedFrame = CalendarPopoverPlacement.aligningTopEdge(
            of: popoverWindow.frame,
            toMenuBarBottom: menuBarWindow.frame.minY
        )
        guard abs(alignedFrame.minY - popoverWindow.frame.minY) > 0.1 else { return }
        popoverWindow.setFrameOrigin(alignedFrame.origin)
    }

    private func dismissCalendarPopover() {
        calendarPresentationPending = false
        calendarPopover?.performClose(nil)
    }

    private func installCalendarDismissMonitors() {
        removeCalendarDismissMonitors()
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        calendarLocalMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            guard let self, self.calendarPopover?.isShown == true else { return event }
            let popoverWindow = self.calendarPopover?.contentViewController?.view.window
            let statusWindow = self.statusItem.button?.window
            if event.type == .leftMouseDown,
               event.window === statusWindow,
               let button = self.statusItem.button,
               button.bounds.contains(button.convert(event.locationInWindow, from: nil)) {
                // Consume the press and close here. Letting the button finish
                // tracking can race the transient popover's own close and
                // immediately reopen it, which looks like the icon did nothing.
                self.dismissCalendarPopover()
                return nil
            }
            if event.window !== popoverWindow, event.window !== statusWindow {
                self.dismissCalendarPopover()
            }
            return event
        }

        calendarGlobalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            Task { @MainActor in
                self?.dismissCalendarPopover()
            }
        }
    }

    private func removeCalendarDismissMonitors() {
        if let calendarLocalMouseMonitor {
            NSEvent.removeMonitor(calendarLocalMouseMonitor)
            self.calendarLocalMouseMonitor = nil
        }
        if let calendarGlobalMouseMonitor {
            NSEvent.removeMonitor(calendarGlobalMouseMonitor)
            self.calendarGlobalMouseMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        removeCalendarDismissMonitors()
        model.setCalendarPresented(false)
        calendarPopover?.contentViewController = nil
        calendarPopover = nil
        updateStatusItem()
    }

    private func statusIconAnchorRect(in button: NSStatusBarButton) -> NSRect {
        if let cell = button.cell as? NSButtonCell {
            let imageRect = cell.imageRect(forBounds: button.bounds)
            if !imageRect.isEmpty {
                // Only borrow the icon's horizontal position. AppKit may move
                // the image a fraction vertically when the title appears or
                // disappears; anchoring that Y value makes the popover gap
                // change with the countdown. The menu-bar button itself has a
                // stable vertical edge, so use its full height instead.
                return NSRect(
                    x: imageRect.minX,
                    y: button.bounds.minY,
                    width: imageRect.width,
                    height: button.bounds.height
                )
            }
        }
        return NSRect(
            x: button.bounds.minX,
            y: button.bounds.minY,
            width: min(19, button.bounds.width),
            height: button.bounds.height
        )
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

    private func installFloatingPanelContentIfNeeded() {
        guard panel != nil, !floatingPanelContentInstalled else { return }
        panel.contentView = NSHostingView(
            rootView: FloatingProgressView(
                model: model,
                openSettings: { [weak self] in self?.presentSettings(tab: .countdown) }
            )
        )
        panel.acceptsMouseMovedEvents = true
        floatingPanelContentInstalled = true
    }

    private func releaseFloatingPanelContent() {
        guard panel != nil, floatingPanelContentInstalled else { return }
        panel.acceptsMouseMovedEvents = false
        panel.contentView = nil
        floatingPanelContentInstalled = false
    }

    private func positionPanelAtTopRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = model.effectivePanelSize
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24))
    }

    private func ensurePanelIsVisible() {
        guard panel != nil else { return }
        let frame = panel.frame
        let mostlyVisible = NSScreen.screens.contains { screen in
            let intersection = screen.visibleFrame.intersection(frame)
            return intersection.width >= frame.width * 0.75 && intersection.height >= frame.height * 0.75
        }
        if !mostlyVisible { positionPanelAtTopRight() }
    }

    private func formattedTime(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    @objc private func toggleFloatingPanelVisibility() {
        guard model.countdownEnabled else { return }
        if model.showFloatingPanel {
            model.showFloatingPanel = false
        } else {
            ensurePanelIsVisible()
            model.showFloatingPanel = true
            panel.orderFrontRegardless()
        }
    }

    @objc private func toggleMenuBarCountdown() {
        guard model.countdownEnabled else { return }
        model.showMenuBarRemaining.toggle()
    }

    @objc private func toggleCowEars() {
        guard model.countdownEnabled else { return }
        model.showCowEars.toggle()
    }

    @objc private func toggleRestToday() {
        guard model.countdownEnabled else { return }
        model.toggleRestToday()
    }

    @objc private func toggleLockPanelPosition() {
        guard model.countdownEnabled else { return }
        model.lockPanelPosition.toggle()
    }

    @objc private func toggleCountdownEnabled() {
        model.countdownEnabled.toggle()
    }

    private func applyCountdownEnabledState(_ enabled: Bool) {
        countdownMasterMenuItem?.title = enabled ? "一键关闭牛马倒计时" : "一键开启牛马倒计时"
        updateCountdownMenuAvailability(enabled)
        updateStatusItem(countdownEnabled: enabled)

        guard panel != nil else { return }
        if enabled && model.showFloatingPanel {
            installFloatingPanelContentIfNeeded()
            ensurePanelIsVisible()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
            releaseFloatingPanelContent()
        }
    }

    private func updateCountdownMenuAvailability(_ enabled: Bool) {
        menuBarCountdownMenuItem?.isEnabled = enabled
        floatingPanelMenuItem?.isEnabled = enabled
        cowEarsMenuItem?.isEnabled = enabled
        lockPositionMenuItem?.isEnabled = enabled
        restMenuItem?.isEnabled = enabled
        menuBarCountdownMenuItem?.isHidden = !enabled
        floatingPanelMenuItem?.isHidden = !enabled
        cowEarsMenuItem?.isHidden = !enabled || !model.showFloatingPanel
        lockPositionMenuItem?.isHidden = !enabled
        restMenuItem?.isHidden = !enabled
    }

    private func configureGlobalHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let delegatePointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let delegateAddress = UInt(bitPattern: userData)
                let actionID = hotKeyID.id
                Task { @MainActor in
                    guard let pointer = UnsafeRawPointer(bitPattern: delegateAddress) else { return }
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
                    delegate.handleGlobalHotKey(actionID)
                }
                return noErr
            },
            1,
            &eventType,
            delegatePointer,
            &hotKeyHandler
        )
        guard installStatus == noErr else { return }

        let modifiers = UInt32(optionKey | shiftKey)
        let calendarID = EventHotKeyID(signature: 0x4E4D484B, id: 1)
        let floatingID = EventHotKeyID(signature: 0x4E4D484B, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_J),
            modifiers,
            calendarID,
            GetApplicationEventTarget(),
            0,
            &calendarHotKey
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            modifiers,
            floatingID,
            GetApplicationEventTarget(),
            0,
            &floatingPanelHotKey
        )
    }

    private func handleGlobalHotKey(_ id: UInt32) {
        switch id {
        case 1:
            toggleCalendarPopover()
        case 2:
            toggleFloatingPanelVisibility()
        default:
            break
        }
    }

    private func unregisterGlobalHotKeys() {
        if let calendarHotKey { UnregisterEventHotKey(calendarHotKey) }
        if let floatingPanelHotKey { UnregisterEventHotKey(floatingPanelHotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        calendarHotKey = nil
        floatingPanelHotKey = nil
        hotKeyHandler = nil
    }

    @objc nonisolated private func systemClockDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.model.resynchronizeAfterSystemTimeChange()
            self?.restorePresentationAfterSystemEvent()
        }
    }

    @objc nonisolated private func calendarDayDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.model.refresh()
            self?.restorePresentationAfterSystemEvent()
        }
    }

    @objc nonisolated private func workspaceDidWake(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.model.refresh()
            self?.restorePresentationAfterSystemEvent()
        }
    }

    @objc nonisolated private func accessibilityDisplayOptionsDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.applyEffectivePanelOpacity()
        }
    }

    private func restorePresentationAfterSystemEvent() {
        statusItem.isVisible = true
        model.refresh()
        ensurePanelIsVisible()
        if model.isFloatingPanelActive {
            installFloatingPanelContentIfNeeded()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
            releaseFloatingPanelContent()
        }
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
        statusMenu.cancelTracking()
        DispatchQueue.main.async { [weak self] in
            self?.presentSettings(tab: .calendar)
        }
    }

    private func presentSettings(tab: SettingsTab) {
        dismissCalendarPopover()
        model.settingsTab = tab
        model.setSettingsPresented(true)
        if settingsWindow == nil {
            let contentSize = NSSize(width: 460, height: 620)
            let view = SettingsView(
                model: model,
                quit: { NSApplication.shared.terminate(nil) }
            )
            let hostingController = NSHostingController(rootView: view)
            hostingController.view.frame = NSRect(origin: .zero, size: contentSize)

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hostingController
            window.setContentSize(contentSize)
            window.contentMinSize = contentSize
            window.contentMaxSize = contentSize
            window.title = "牛马日历设置"
            window.animationBehavior = .none
            addVersionToTitleBar(of: window)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }

        guard let settingsWindow else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow.contentView?.layoutSubtreeIfNeeded()
        settingsWindow.contentView?.displayIfNeeded()
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    private func addVersionToTitleBar(of window: NSWindow) {
        let label = NSTextField(labelWithString: AppVersion.displayText)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 108, height: 28))
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = container
        window.addTitlebarAccessoryViewController(accessory)
    }

    @objc private func openAbout() {
        statusMenu.cancelTracking()
        DispatchQueue.main.async { [weak self] in
            self?.presentSettings(tab: .about)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === settingsWindow else { return }
        model.setSettingsPresented(false)
        settingsWindow = nil
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        restorePresentationAfterSystemEvent()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.refresh()
        restorePresentationAfterSystemEvent()
        model.refreshLaunchAtLoginStatus()
        if calendarPresentationPending {
            calendarPresentationPending = false
            presentCalendarPopover()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.refresh()
        restorePresentationAfterSystemEvent()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKeys()
        removeCalendarDismissMonitors()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

}
