import Foundation

/// A Chromium browser Ririku can talk to. They all use the same native messaging protocol and
/// the same unpacked extension ID, so only the folder for the host manifest and the address of
/// the extensions page differ.
public struct Browser: Sendable, Equatable, Identifiable {
    /// A product name, so it is never translated.
    public let name: String
    public let bundleID: String
    /// Relative to `~/Library/Application Support`.
    public let supportFolder: String
    public let extensionsPage: String

    public var id: String { bundleID }

    public init(name: String, bundleID: String, supportFolder: String, extensionsPage: String) {
        self.name = name
        self.bundleID = bundleID
        self.supportFolder = supportFolder
        self.extensionsPage = extensionsPage
    }

    /// Chrome stays first, because it is the browser the project targets first.
    /// Arc's folder is the one place that still needs to be confirmed on a real install.
    public static let all: [Browser] = [
        Browser(name: "Chrome", bundleID: "com.google.Chrome",
                supportFolder: "Google/Chrome", extensionsPage: "chrome://extensions"),
        Browser(name: "Brave", bundleID: "com.brave.Browser",
                supportFolder: "BraveSoftware/Brave-Browser", extensionsPage: "brave://extensions"),
        Browser(name: "Edge", bundleID: "com.microsoft.edgemac",
                supportFolder: "Microsoft Edge", extensionsPage: "edge://extensions"),
        Browser(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi",
                supportFolder: "Vivaldi", extensionsPage: "vivaldi://extensions"),
        Browser(name: "Opera", bundleID: "com.operasoftware.Opera",
                supportFolder: "com.operasoftware.Opera", extensionsPage: "opera://extensions"),
        Browser(name: "Chromium", bundleID: "org.chromium.Chromium",
                supportFolder: "Chromium", extensionsPage: "chrome://extensions"),
        Browser(name: "Arc", bundleID: "company.thebrowser.Browser",
                supportFolder: "Arc/User Data", extensionsPage: "arc://extensions")
    ]

    public static func named(_ name: String) -> Browser? { all.first { $0.name == name } }
    public static func with(bundleID: String) -> Browser? { all.first { $0.bundleID == bundleID } }

    /// Identifies the browser that launched a process, used by the native host to name its own browser.
    /// Walks up from the executable to the enclosing `.app` and reads its bundle identifier, so it
    /// works wherever the browser is installed.
    public static func containing(executablePath: String) -> Browser? {
        var url = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath()
        while url.pathComponents.count > 1 {
            url = url.deletingLastPathComponent()
            guard url.pathExtension == "app" else { continue }
            guard let plist = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
                  let metadata = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
                  let identifier = metadata["CFBundleIdentifier"] as? String else { return nil }
            return with(bundleID: identifier)
        }
        return nil
    }
}
