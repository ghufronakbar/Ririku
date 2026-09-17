import AppKit
import SwiftUI
import NotchCore

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
    private var popupWork: DispatchWorkItem?
    private var hovered = false

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
        panel.contentView = NSHostingView(rootView: PlayerView(model: model, hoverChanged: { [weak self] inside in self?.hover(inside) }))
        model.geometryChanged = { [weak self] in self?.positionPanel() }
        model.openSetup = { [weak self] in self?.showSetup() }
        model.trackChanged = { [weak self] in self?.showTrackPopup() }
        model.sendPacket = { [weak self] data in self?.bridge.send(data) }
        bridge.onPacket = { [weak self] data in self?.model.receive(data) }
        bridge.onDisconnect = { [weak self] in self?.model.disconnect() }
        do { try bridge.start() }
        catch { model.bridgeError = error.localizedDescription }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        positionPanel()
        panel.orderFrontRegardless()
        if !UserDefaults.standard.bool(forKey: "didShowSetup") {
            showSetup()
            UserDefaults.standard.set(true, forKey: "didShowSetup")
        }
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Notch Box")
        let menu = NSMenu()
        let setup = menu.addItem(withTitle: "Setup…", action: #selector(showSetup), keyEquivalent: ",")
        setup.target = self
        let expand = menu.addItem(withTitle: "Buka panel musik", action: #selector(expandPanel), keyEquivalent: "")
        expand.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Keluar Notch Box", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func showSetup() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 700), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Notch Box — Setup"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SetupView(model: model))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func expandPanel() { model.expanded = true; panel.makeKeyAndOrderFront(nil) }
    @objc private func screenChanged() { positionPanel() }

    private func positionPanel() {
        guard panel != nil, let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let top = max(32, screen.safeAreaInsets.top)
        let notch: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = max(180, right.minX - left.maxX)
        } else { notch = 180 }
        if model.notchWidth != notch { model.notchWidth = notch }
        if model.topHeight != top { model.topHeight = top }
        let active = model.current != nil
        let width = min(screen.frame.width - 24, model.expanded ? max(model.panelWidth, notch + 120) : active ? notch + 100 : notch)
        let height = top + (model.expanded ? (model.commandError == nil ? 286 : 316) : active && model.showLyrics ? 34 : 0)
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        if model.canAnimate && panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in context.duration = 0.24; panel.animator().setFrame(frame, display: true) }
        } else { panel.setFrame(frame, display: true) }
    }

    private func hover(_ inside: Bool) {
        hovered = inside
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !inside && self.panel.isKeyWindow { return }
            self.model.expanded = inside
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? 0.15 : 0.35), execute: work)
    }

    private func showTrackPopup() {
        popupWork?.cancel()
        guard !model.expanded else { return }
        model.expanded = true
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.hovered, !self.panel.isKeyWindow else { return }
            self.model.expanded = false
        }
        popupWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func applicationWillTerminate(_ notification: Notification) { bridge.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSetup(); return false }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
