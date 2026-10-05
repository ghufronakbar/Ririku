import NaturalLanguage
import SwiftUI
@preconcurrency import Translation
import RirikuCore

/// Whether a language pair can be translated on this Mac.
enum TranslationAvailability {
    case installed, downloadable, unsupported
}

/// Apple's on-device Translation framework (D-019, R-WID-10). It needs macOS 15; on macOS 14 Translate and lyric
/// translation are turned off with an explanation. Text never leaves the Mac, and is never logged (R-SEC-6).
@MainActor
enum TranslationService {
    static var isAvailable: Bool {
        if #available(macOS 15, *) { return true }
        return false
    }

    private static var cachedLanguages: [String]?

    /// The languages translation offers, as BCP 47 codes such as `en`, `ja`, or `zh-TW`.
    static func languages() async -> [String] {
        if let cachedLanguages { return cachedLanguages }
        guard #available(macOS 15, *) else { return [] }
        let languages = await LanguageAvailability().supportedLanguages.map(\.minimalIdentifier)
        cachedLanguages = languages
        return languages
    }

    static func availability(from source: String, to target: String) async -> TranslationAvailability {
        guard #available(macOS 15, *) else { return .unsupported }
        switch await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target)) {
        case .installed: return .installed
        case .supported: return .downloadable
        default: return .unsupported
        }
    }

    /// The main language of a text, as a code from `languages`, or nil when it is not recognized or not offered.
    static func detect(_ text: String, in languages: [String]) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage.flatMap { TranslationLanguage.match($0.rawValue, in: languages) }
    }

    /// True when a short text is clearly in `language` already, such as an English line in a Japanese song.
    static func isClearly(_ text: String, in language: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).first, best.value >= 0.8 else { return false }
        return TranslationLanguage.same(best.key.rawValue, language)
    }

    /// The name of a language in the interface language, telling apart languages that share a code.
    static func name(_ code: String, among languages: [String], locale: Locale) -> String {
        let identifier = TranslationLanguage.displayIdentifier(code, among: languages)
        return locale.localizedString(forIdentifier: identifier) ?? code
    }

    /// The language alone, without its region or script: "English" rather than "English (United States)".
    static func languageName(_ code: String, locale: Locale) -> String {
        let language = Locale.Language(identifier: code).languageCode?.identifier ?? code
        return locale.localizedString(forLanguageCode: language) ?? code
    }

    /// System Settings → General → Language & Region, where downloaded translation languages are managed.
    static func openLanguageSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// A language pair to download, from a button in Setup.
struct TranslationDownload: Equatable {
    let id = UUID()
    let source: String
    let target: String
}

extension View {
    /// Asks macOS to download the languages of `download`. Used only in Setup: the system's download prompt is
    /// reliable in a normal window, unlike the notch panel (D-027).
    @ViewBuilder
    func translationDownload(_ download: TranslationDownload?, finished: @escaping () -> Void) -> some View {
        if #available(macOS 15, *) {
            modifier(TranslationDownloadModifier(download: download, finished: finished))
        } else {
            self
        }
    }
}

@available(macOS 15, *)
private struct TranslationDownloadModifier: ViewModifier {
    let download: TranslationDownload?
    let finished: () -> Void
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                try? await session.prepareTranslation()
                finished()
            }
            .onChange(of: download) { _, download in
                guard let download else { return }
                configuration = .pair(source: download.source, target: download.target, reusing: configuration)
            }
    }
}

@available(macOS 15, *)
extension TranslationSession.Configuration {
    /// A configuration for the pair. Reusing the same pair invalidates it instead, which runs the task again.
    static func pair(source: String, target: String, reusing current: Self?) -> Self {
        let source = Locale.Language(identifier: source), target = Locale.Language(identifier: target)
        if var current, current.source == source, current.target == target {
            current.invalidate()
            return current
        }
        return Self(source: source, target: target)
    }
}
