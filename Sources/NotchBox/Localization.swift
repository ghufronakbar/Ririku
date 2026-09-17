import Foundation
import NotchCore

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system, en, id, ja

    static let supportedCodes = ["en", "id", "ja"]
    var id: String { rawValue }

    /// Mode sistem memilih bahasa pertama yang didukung dari preferensi macOS, lalu English.
    var resolvedCode: String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: Self.supportedCodes, forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    /// Nama bahasa selalu ditulis dalam bahasanya sendiri.
    static func nativeName(of code: String) -> String {
        switch code {
        case "id": return "Bahasa Indonesia"
        case "ja": return "日本語"
        default: return "English"
        }
    }
}

/// Teks UI yang disimpan sebagai key English + argumen, lalu diterjemahkan saat ditampilkan
/// agar status lama ikut berganti ketika bahasa diubah.
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

/// Mencari terjemahan langsung di `<kode>.lproj` bundle aplikasi sehingga bahasa dapat diganti tanpa restart.
/// Key adalah teks English; tanpa berkas terjemahan (mis. binary di luar bundle) teks English yang tampil.
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
