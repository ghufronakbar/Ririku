import Foundation
import ServiceManagement
import Testing
@testable import Ririku
@testable import RirikuCore

/// The test binary is not an app bundle, so these tests never read or change the real login items.
@Suite("Launch at login")
struct LoginItemTests {
    @Test("Translates the system status into an interface state")
    func mapsStatus() {
        #expect(LoginItem.state(available: true, translocated: false, status: .enabled) == .on)
        #expect(LoginItem.state(available: true, translocated: false, status: .notRegistered) == .off)
        #expect(LoginItem.state(available: true, translocated: false, status: .notFound) == .off)
        #expect(LoginItem.state(available: true, translocated: false, status: .requiresApproval) == .needsApproval)
    }

    @Test("A missing bundle or a translocated copy outranks the system status")
    func reportsUnusableLocations() {
        #expect(LoginItem.state(available: false, translocated: false, status: .enabled) == .unavailable)
        #expect(LoginItem.state(available: false, translocated: true, status: .enabled) == .unavailable)
        #expect(LoginItem.state(available: true, translocated: true, status: .enabled) == .translocated)
    }

    @Test("Refuses to register outside an app bundle")
    func requiresAppBundle() {
        #expect(!LoginItem.isAvailable)
        #expect(LoginItem.state() == .unavailable)
        #expect(throws: BridgeError.self) { try LoginItem.setEnabled(true) }
        #expect(throws: BridgeError.self) { try LoginItem.setEnabled(false) }
    }

    @Test("Points at the Login Items pane of System Settings")
    func opensLoginItemsSettings() {
        #expect(LoginItem.settingsURL.scheme == "x-apple.systempreferences")
        #expect(LoginItem.settingsURL.absoluteString.contains("LoginItems"))
    }

    @MainActor
    @Test("Reports the failure and keeps the interface in step with macOS")
    func reportsFailureInSetup() {
        let cache = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-lyrics-\(UUID().uuidString)")
        let model = AppModel(lyricsService: LyricsService(cacheDirectory: cache), defaults: MemoryDefaults())
        model.interfaceLanguage = .en
        let revision = model.loginItemRevision
        model.setLaunchAtLogin(true)
        #expect(!model.launchAtLogin)
        #expect(model.loginItemMessage?.key == "Open Ririku from its app bundle to open it at login.")
        #expect(model.loginItemRevision == revision + 1)
        model.refreshLoginItem()
        #expect(model.loginItemRevision == revision + 2)
    }
}
