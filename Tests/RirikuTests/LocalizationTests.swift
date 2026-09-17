import Foundation
import Testing
@testable import Ririku
@testable import RirikuCore

@Suite("Interface language")
struct InterfaceLanguageTests {
    @Test("An explicit choice resolves to itself")
    func resolvesExplicitLanguage() {
        #expect(InterfaceLanguage.en.resolvedCode == "en")
        #expect(InterfaceLanguage.id.resolvedCode == "id")
        #expect(InterfaceLanguage.ja.resolvedCode == "ja")
    }

    @Test("System mode resolves to a supported language")
    func resolvesSystemLanguage() {
        #expect(InterfaceLanguage.supportedCodes.contains(InterfaceLanguage.system.resolvedCode))
    }

    @Test("Language names are written in their own language")
    func namesLanguages() {
        #expect(InterfaceLanguage.nativeName(of: "en") == "English")
        #expect(InterfaceLanguage.nativeName(of: "id") == "Bahasa Indonesia")
        #expect(InterfaceLanguage.nativeName(of: "ja") == "日本語")
        #expect(InterfaceLanguage.nativeName(of: "fr") == "English", "unknown codes fall back to English")
    }
}

@Suite("UIText and Localizer")
struct UITextTests {
    @Test("Keeps a bridge error's key and arguments so it can be translated")
    func wrapsBridgeError() {
        let text = UIText(error: BridgeError.system("Lyrics service limit reached. Try again in %@ s.", ["42"]))
        #expect(text.key == "Lyrics service limit reached. Try again in %@ s.")
        #expect(text.arguments == ["42"])
    }

    @Test("Wraps other errors verbatim")
    func wrapsSystemError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network offline"])
        let text = UIText(error: error)
        #expect(text.key == "%@")
        #expect(text.arguments == ["Network offline"])
    }

    @Test("Without translation files the English key is used")
    func fallsBackToEnglishKeys() {
        let localizer = Localizer(code: "ja")
        #expect(localizer.code == "ja")
        #expect(localizer.string("Lyrics not found") == "Lyrics not found")
    }

    @Test("Fills placeholders, including positional ones")
    func formatsArguments() {
        let localizer = Localizer(code: "en")
        #expect(localizer.string("Selected #%@.", ["7"]) == "Selected #7.")
        #expect(localizer.string("%2$@ — %1$@", ["song", "artist"]) == "artist — song")
        #expect(localizer.string("%@", ["100% raw"]) == "100% raw", "arguments are not reformatted")
    }
}

@Suite("Browser setup outside an app bundle")
struct BrowserSetupTests {
    @Test("Reports that registration needs the app bundle")
    func requiresAppBundle() {
        let chrome = Browser.named("Chrome")!
        #expect(BrowserSetup.hostExecutableURL == nil)
        #expect(BrowserSetup.bundledExtensionURL == nil)
        #expect(BrowserSetup.hostStatus(for: chrome) == .unavailable)
        #expect(throws: BridgeError.self) { try BrowserSetup.registerHost(for: chrome) }
        #expect(throws: BridgeError.self) { _ = try BrowserSetup.installExtension() }
    }

    @Test("Reads an extension version from a manifest")
    func readsExtensionVersion() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-ext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(BrowserSetup.extensionVersion(at: folder) == nil)
        try #"{"version":"9.9.9"}"#.write(to: folder.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        #expect(BrowserSetup.extensionVersion(at: folder) == "9.9.9")
        try "not json".write(to: folder.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        #expect(BrowserSetup.extensionVersion(at: folder) == nil)
    }

    @Test("Uses the fixed extension id and host name")
    func usesFixedIdentifiers() {
        #expect(BrowserSetup.extensionID == "bmmbkmngcmjoihlcmehlnfpedhoefofi")
        #expect(BrowserSetup.hostName == "io.github.lanstheprodigy.ririku.bridge")
        #expect(BrowserSetup.manifestURL(for: Browser.named("Chrome")!).lastPathComponent == "io.github.lanstheprodigy.ririku.bridge.json")
    }

    @Test("Writes the host manifest into each browser's own folder")
    func usesBrowserFolders() {
        func folder(_ name: String) -> String {
            BrowserSetup.manifestURL(for: Browser.named(name)!).deletingLastPathComponent().path
        }
        #expect(folder("Chrome").hasSuffix("Application Support/Google/Chrome/NativeMessagingHosts"))
        #expect(folder("Brave").hasSuffix("Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"))
        #expect(folder("Edge").hasSuffix("Application Support/Microsoft Edge/NativeMessagingHosts"))
        #expect(Set(Browser.all.map(\.supportFolder)).count == Browser.all.count, "each browser needs its own folder")
    }
}

@Suite("Browser catalogue")
struct BrowserTests {
    @Test("Chrome comes first and every entry is unique")
    func listsBrowsers() {
        #expect(Browser.all.first?.name == "Chrome")
        #expect(Set(Browser.all.map(\.bundleID)).count == Browser.all.count)
        #expect(Set(Browser.all.map(\.name)).count == Browser.all.count)
        #expect(Browser.all.allSatisfy { $0.extensionsPage.hasSuffix("://extensions") })
        #expect(Browser.named("Brave")?.bundleID == "com.brave.Browser")
        #expect(Browser.named("Safari") == nil, "only Chromium browsers are listed")
        #expect(Browser.with(bundleID: "com.microsoft.edgemac")?.name == "Edge")
    }

    @MainActor
    @Test("Labels the playing source with the browser that connected")
    func labelsTheConnectedBrowser() throws {
        let cache = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-lyrics-\(UUID().uuidString)")
        let model = AppModel(lyricsService: LyricsService(cacheDirectory: cache), defaults: MemoryDefaults())
        model.interfaceLanguage = .en
        let packet: [String: Any] = [
            "protocolVersion": 1, "kind": "snapshot", "sessionId": "s", "sourceId": "tab:1",
            "sourceLabel": "YouTube Music · Chrome", "sequence": 1, "trackId": "abc", "title": "Song",
            "artist": "Artist", "position": 1, "duration": 100, "playbackRate": 1, "state": "playing",
            "isAdvertisement": false, "capabilities": ["playPause": true, "previous": false, "next": false, "seek": true]
        ]
        let snapshot = try JSONDecoder().decode(PlaybackSnapshot.self, from: JSONSerialization.data(withJSONObject: packet))
        #expect(model.sourceLabel(for: snapshot) == "YouTube Music · Chrome", "without a host the extension label is kept")

        func hostPacket(_ browser: String) -> Data {
            try! JSONSerialization.data(withJSONObject: ["protocolVersion": 1, "kind": "host", "browser": browser])
        }
        model.receive(hostPacket("Brave"))
        #expect(model.connectedBrowser == "Brave")
        #expect(model.sourceLabel(for: snapshot) == "YouTube Music · Brave")

        model.receive(hostPacket("Safari"))
        #expect(model.connectedBrowser == nil, "only known browser names are accepted")
        model.receive(hostPacket("Edge"))
        model.disconnect()
        #expect(model.connectedBrowser == nil)
    }

    @Test("Names the browser that launched a process from its bundle")
    func readsBundleIdentifier() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-app-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Brave Browser.app/Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = app.appendingPathComponent("Brave Browser").path
        #expect(Browser.containing(executablePath: executable) == nil, "a bundle without an Info.plist names nothing")
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.brave.Browser"], format: .xml, options: 0)
        try plist.write(to: app.deletingLastPathComponent().appendingPathComponent("Info.plist"))
        #expect(Browser.containing(executablePath: executable)?.name == "Brave")
        #expect(Browser.containing(executablePath: "/bin/zsh") == nil)
    }
}
