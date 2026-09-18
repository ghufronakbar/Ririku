import AppKit
import SwiftUI
import RirikuCore

final class NotchPanel: NSPanel {
    var dismissPanel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismissPanel?() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let bridge = BridgeServer()
    private var panel: NotchPanel!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var hoverWork: DispatchWorkItem?
    private var resizeTimer: Timer?
    private var targetPanelFrame: NSRect?

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.dismissPanel = { [weak self] in self?.panel.resignKey(); self?.model.expanded = false }
        let hosting = NSHostingView(rootView: PlayerView(model: model, hoverChanged: { [weak self] inside in self?.hover(inside) }))
        hosting.sizingOptions = []
        panel.contentView = hosting
        model.geometryChanged = { [weak self] in self?.positionPanel() }
        model.openSetup = { [weak self] in self?.showSetup() }
        model.sendPacket = { [weak self] data in self?.bridge.send(data) }
        model.startDesktopPlayers()
        model.languageChanged = { [weak self] in self?.applyLanguage() }
        bridge.setLanguage(model.localizer.code)
        bridge.onPacket = { [weak self] data in self?.model.receive(data) }
        bridge.onDisconnect = { [weak self] in self?.model.disconnect() }
        do { try bridge.start() }
        catch { model.bridgeError = UIText(error: error) }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        positionPanel()
        panel.orderFrontRegardless()
        if !UserDefaults.standard.bool(forKey: "didShowSetup") {
            showSetup()
            UserDefaults.standard.set(true, forKey: "didShowSetup")
        }
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Ririku")
        let menu = NSMenu()
        let setup = menu.addItem(withTitle: model.t("Setup…"), action: #selector(showSetup), keyEquivalent: ",")
        setup.target = self
        let expand = menu.addItem(withTitle: model.t("Open music panel"), action: #selector(expandPanel), keyEquivalent: "")
        expand.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: model.t("Quit Ririku"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func applyLanguage() {
        let items = statusItem.menu?.items ?? []
        if items.count == 4 {
            items[0].title = model.t("Setup…")
            items[1].title = model.t("Open music panel")
            items[3].title = model.t("Quit Ririku")
        }
        settingsWindow?.title = model.t("Ririku — Setup")
        bridge.setLanguage(model.localizer.code)
    }

    @objc private func showSetup() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 700), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = model.t("Ririku — Setup")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SetupView(model: model))
            window.center()
            settingsWindow = window
        }
        model.refreshLoginItem()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func expandPanel() { model.expanded = true; panel.makeKeyAndOrderFront(nil) }
    @objc private func screenChanged() { positionPanel(animate: false) }
    @objc private func accessibilityChanged() { model.objectWillChange.send(); positionPanel(animate: false) }

    private func positionPanel(animate: Bool = true) {
        guard panel != nil, let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let top = max(32, screen.safeAreaInsets.top)
        let notch: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX {
            notch = right.minX - left.maxX
        } else { notch = 180 }
        if model.notchWidth != notch { model.notchWidth = notch }
        if model.topHeight != top { model.topHeight = top }
        let size = model.panelSize(screenWidth: screen.frame.width)
        let width = size.width
        let height = size.height
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        if !animate || !model.canAnimate || !panel.isVisible {
            resizeTimer?.invalidate()
            resizeTimer = nil
            targetPanelFrame = frame
            panel.setFrame(frame, display: true)
            return
        }
        guard targetPanelFrame != frame else { return }
        targetPanelFrame = frame
        resizeTimer?.invalidate()
        let start = panel.frame
        let startedAt = ProcessInfo.processInfo.systemUptime
        let duration = model.popupDuration
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - startedAt) / duration)
                self.panel.setFrame(IslandMotion.frame(from: start, to: frame, progress: progress), display: true)
                if progress >= 1 {
                    timer.invalidate()
                    self.resizeTimer = nil
                }
            }
        }
        resizeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func hover(_ inside: Bool) {
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !inside && self.panel.isKeyWindow { return }
            self.model.expanded = inside
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? 0.15 : 0.35), execute: work)
    }

    func applicationWillTerminate(_ notification: Notification) { resizeTimer?.invalidate(); bridge.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSetup(); return false }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
