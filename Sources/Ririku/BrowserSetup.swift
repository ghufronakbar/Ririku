import AppKit
import Foundation
import RirikuCore

/// Browser setup without Terminal. The extension ID is fixed because its manifest carries a `key`,
/// and every Chromium browser derives the same ID from it, so the app can write the native host
/// manifest for each installed browser itself and copy the extension for Load unpacked.
enum BrowserSetup {
    static let extensionID = "bmmbkmngcmjoihlcmehlnfpedhoefofi"
    static let hostName = "io.github.lanstheprodigy.ririku.bridge"

    enum HostStatus: Equatable {
        case unavailable, translocated, notRegistered, needsUpdate, registered
    }

    /// Test harnesses point this at a temporary folder so they never touch a real browser profile.
    static var home = FileManager.default.homeDirectoryForCurrentUser
    private static var origin: String { "chrome-extension://\(extensionID)/" }

    /// Only browsers that are actually installed are offered, because a folder alone can be left
    /// behind by another application.
    static func installedBrowsers() -> [Browser] {
        Browser.all.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }

    static func manifestURL(for browser: Browser) -> URL {
        home.appendingPathComponent("Library/Application Support/\(browser.supportFolder)/NativeMessagingHosts/\(hostName).json")
    }

    static var installedExtensionURL: URL {
        home.appendingPathComponent("Library/Application Support/Ririku/Chrome Extension", isDirectory: true)
    }

    /// Available only when the app runs from the `.app` bundle produced by `build-app.sh`.
    static var hostExecutableURL: URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/RirikuHost")
        return Bundle.main.bundleURL.pathExtension == "app" && FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static var bundledExtensionURL: URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/ChromeExtension", isDirectory: true)
        return extensionVersion(at: url) == nil ? nil : url
    }

    /// macOS runs a downloaded app that was never moved from a temporary path, which disappears after it quits.
    static var isTranslocated: Bool { Bundle.main.bundlePath.contains("/AppTranslocation/") }

    static var bundledExtensionVersion: String? { bundledExtensionURL.flatMap(extensionVersion(at:)) }
    static var installedExtensionVersion: String? { extensionVersion(at: installedExtensionURL) }

    static func hostStatus(for browser: Browser) -> HostStatus {
        guard let host = hostExecutableURL else { return .unavailable }
        if isTranslocated { return .translocated }
        guard let data = try? Data(contentsOf: manifestURL(for: browser)) else { return .notRegistered }
        guard let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              manifest["name"] as? String == hostName, manifest["path"] as? String == host.path,
              (manifest["allowed_origins"] as? [String])?.contains(origin) == true else { return .needsUpdate }
        return .registered
    }

    /// Registers every installed browser, so the user clicks once no matter how many they use.
    /// The first failure is reported, and the browsers registered before it keep their manifest.
    static func registerHosts() throws -> [Browser] {
        let browsers = installedBrowsers()
        guard !browsers.isEmpty else {
            throw BridgeError.system("No supported browser found. Ririku works with Chrome, Brave, Edge, Vivaldi, Opera, Chromium, and Arc.")
        }
        for browser in browsers { try registerHost(for: browser) }
        return browsers
    }

    static func registerHost(for browser: Browser) throws {
        guard let host = hostExecutableURL else { throw BridgeError.system("Open Ririku from its app bundle to connect a browser.") }
        guard !isTranslocated else { throw BridgeError.system("Move Ririku to the Applications folder and open it again before connecting a browser.") }
        let manifest: [String: Any] = [
            "name": hostName, "description": "Ririku local music bridge", "path": host.path,
            "type": "stdio", "allowed_origins": [origin]
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let url = manifestURL(for: browser)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Copies the bundled extension into Application Support so it can be picked in the Load unpacked dialog.
    static func installExtension() throws -> URL {
        guard let source = bundledExtensionURL else { throw BridgeError.system("Open Ririku from its app bundle to copy the extension.") }
        let files = FileManager.default
        let target = installedExtensionURL
        try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = target.deletingLastPathComponent().appendingPathComponent(".Chrome Extension-\(UUID().uuidString)", isDirectory: true)
        do {
            try files.copyItem(at: source, to: staging)
            if files.fileExists(atPath: target.path) {
                _ = try files.replaceItemAt(target, withItemAt: staging)
            } else {
                try files.moveItem(at: staging, to: target)
            }
        } catch {
            try? files.removeItem(at: staging)
            throw error
        }
        return target
    }

    static func extensionVersion(at folder: URL) -> String? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return manifest["version"] as? String
    }
}
