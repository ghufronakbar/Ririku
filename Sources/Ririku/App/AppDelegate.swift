import AppKit
import SwiftUI
import RirikuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let bridge = BridgeServer()
    private var panel: PanelController!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        panel = PanelController(model: model)
        model.openSetup = { [weak self] in self?.showSetup() }
        model.music.sendPacket = { [weak self] data in self?.bridge.send(data) }
        model.music.startDesktopPlayers()
        model.languageChanged = { [weak self] in self?.applyLanguage() }
        bridge.setLanguage(model.localizer.code)
        bridge.onPacket = { [weak self] data in self?.model.music.receive(data) }
        bridge.onDisconnect = { [weak self] in self?.model.music.disconnect() }
        do { try bridge.start() }
        catch { model.music.bridgeError = UIText(error: error) }
        panel.show()
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
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 640),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = model.t("Ririku — Setup")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SetupView(model: model))
            window.contentMinSize = NSSize(width: SetupView.minimumSize.width, height: SetupView.minimumSize.height)
            window.center()
            settingsWindow = window
        }
        model.refreshLoginItem()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func expandPanel() { panel.expandFromMenu() }

    func applicationWillTerminate(_ notification: Notification) { panel?.stop(); bridge.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSetup(); return false }
}
