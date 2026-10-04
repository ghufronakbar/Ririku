import Foundation
import RirikuCore

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system, en, id, ja

    static let supportedCodes = ["en", "id", "ja"]
    var id: String { rawValue }

    /// System mode picks the first supported language from the macOS preferences, otherwise English.
    var resolvedCode: String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: Self.supportedCodes, forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    /// A language name is always written in that language.
    static func nativeName(of code: String) -> String {
        switch code {
        case "id": return "Bahasa Indonesia"
        case "ja": return "日本語"
        default: return "English"
        }
    }
}

/// Interface text stored as an English key plus arguments and translated when displayed,
/// so statuses kept in the model follow a language change.
struct UIText: Equatable {
    let key: String
    let arguments: [String]

    init(_ key: String, _ arguments: String...) {
        self.key = key
        self.arguments = arguments
    }

    init(error: Error) {
        if let bridge = error as? BridgeError {
            (key, arguments) = bridge.message
        } else {
            key = "%@"
            arguments = [error.localizedDescription]
        }
    }
}

/// Looks translations up in the app bundle's `<code>.lproj` directly, so the language can change without a restart.
/// Keys are the English text; without a translation file (for example a binary outside the bundle) English is shown.
struct Localizer {
    let code: String
    let locale: Locale
    private let bundle: Bundle?

    init(code: String) {
        self.code = code
        locale = Locale(identifier: code)
        bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    func string(_ key: String, _ arguments: [String] = []) -> String {
        let format = bundle?.localizedString(forKey: key, value: key, table: nil) ?? key
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments.map { $0 as NSString as CVarArg })
    }
}
