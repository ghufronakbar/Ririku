import Foundation
import ServiceManagement
import RirikuCore

/// Launch at login through `SMAppService`, which registers the app bundle itself, so no helper
/// tool or Terminal command is needed. Only the `.app` from `build-app.sh` can be registered:
/// a plain executable or a translocated copy has no stable path for macOS to open at login.
enum LoginItem {
    enum State: Equatable {
        /// Not running from an `.app` bundle, for example `swift run` or the test harness.
        case unavailable
        /// Running from the App Translocation path, which disappears after the app quits.
        case translocated
        case off
        case on
        /// Registered, but macOS waits for the user to allow it in System Settings.
        case needsApproval
    }

    /// Opens the pane that lists login items, for the approval and off-by-choice cases.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    /// Kept separate from the system lookup so tests can check every combination.
    static func state(available: Bool, translocated: Bool, status: SMAppService.Status) -> State {
        guard available else { return .unavailable }
        guard !translocated else { return .translocated }
        switch status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        default: return .off
        }
    }

    static func state() -> State {
        guard isAvailable, !BrowserSetup.isTranslocated else {
            return state(available: isAvailable, translocated: BrowserSetup.isTranslocated, status: .notRegistered)
        }
        return state(available: true, translocated: false, status: SMAppService.mainApp.status)
    }

    /// Turning it off is allowed even from a translocated copy, so an old registration can be removed.
    static func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else {
            throw BridgeError.system("Open Ririku from its app bundle to open it at login.")
        }
        guard !enabled || !BrowserSetup.isTranslocated else {
            throw BridgeError.system("Move Ririku to the Applications folder and open it again before opening it at login.")
        }
        if enabled {
            try SMAppService.mainApp.register()
        } else if SMAppService.mainApp.status != .notRegistered {
            // Unregistering something that was never registered reports an error instead of doing nothing.
            try SMAppService.mainApp.unregister()
        }
    }
}
