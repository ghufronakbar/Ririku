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

@Suite("Chrome setup outside an app bundle")
struct ChromeSetupTests {
    @Test("Reports that registration needs the app bundle")
    func requiresAppBundle() {
        #expect(ChromeSetup.hostExecutableURL == nil)
        #expect(ChromeSetup.bundledExtensionURL == nil)
        #expect(ChromeSetup.hostStatus() == .unavailable)
        #expect(throws: BridgeError.self) { try ChromeSetup.registerHost() }
        #expect(throws: BridgeError.self) { _ = try ChromeSetup.installExtension() }
    }

    @Test("Reads an extension version from a manifest")
    func readsExtensionVersion() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-ext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(ChromeSetup.extensionVersion(at: folder) == nil)
        try #"{"version":"9.9.9"}"#.write(to: folder.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        #expect(ChromeSetup.extensionVersion(at: folder) == "9.9.9")
        try "not json".write(to: folder.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        #expect(ChromeSetup.extensionVersion(at: folder) == nil)
    }

    @Test("Uses the fixed extension id and host name")
    func usesFixedIdentifiers() {
        #expect(ChromeSetup.extensionID == "bmmbkmngcmjoihlcmehlnfpedhoefofi")
        #expect(ChromeSetup.hostName == "io.github.lanstheprodigy.ririku.bridge")
        #expect(ChromeSetup.manifestURL.lastPathComponent == "io.github.lanstheprodigy.ririku.bridge.json")
    }
}
