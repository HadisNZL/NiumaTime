import AppKit
import Combine
import SwiftUI

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
    private var panel: NSPanel!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePanel()
        observeModel()
        updateStatusItem()
        if model.showFloatingPanel { panel.orderFrontRegardless() }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "牛马进度")
            button.imagePosition = .imageLeading
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "显示并找回牛马", action: #selector(revealPanel), keyEquivalent: "r")
        menu.addItem(withTitle: "隐藏牛马", action: #selector(hidePanel), keyEquivalent: "p")
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出牛马", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func configurePanel() {
        let size = model.effectiveWidgetSize
        let content = FloatingProgressView(
            model: model,
            openSettings: { [weak self] in self?.openSettings() }
        )

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
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
        panel.isMovableByWindowBackground = true
        panel.alphaValue = model.panelOpacity
        panel.setFrameAutosaveName("WorkhorseCirclePanel")

        if !panel.setFrameUsingName("WorkhorseCirclePanel") {
            positionPanelAtTopRight()
        }
        resizeCircle(to: size, preserveCenter: true)
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
        Publishers.CombineLatest(model.$circleSize, model.$beaconDiameter)
            .dropFirst()
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.resizeCircle(to: self.model.effectiveWidgetSize, preserveCenter: true)
            }
            .store(in: &cancellables)
        model.$panelOpacity
            .sink { [weak self] value in self?.panel?.alphaValue = value }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = model.showMenuBarRemaining ? " \(model.compactStatusText)" : ""
        button.toolTip = "牛马 · \(formattedTime(model.startMinutes))–\(formattedTime(model.endMinutes)) · \(model.statusText)"
    }

    private func resizeCircle(to size: Double, preserveCenter: Bool) {
        guard panel != nil else { return }
        var frame = panel.frame
        if preserveCenter {
            frame.origin.x += (frame.width - size) / 2
            frame.origin.y += (frame.height - size) / 2
        }
        frame.size = NSSize(width: size, height: size)
        panel.setFrame(frame, display: true, animate: true)
    }

    private func positionPanelAtTopRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = model.effectiveWidgetSize
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size - 24, y: visible.maxY - size - 24))
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
}
