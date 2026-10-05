import Foundation

/// Language codes for on-device translation (D-019). Codes are BCP 47 identifiers such as `en`, `ja`, or `zh-TW`.
public enum TranslationLanguage {
    /// The supported language that a detected language belongs to: the same language and script, preferring the
    /// same region. Language detection says `zh-Hant` where translation offers `zh-TW`, for example.
    public static func match(_ detected: String, in supported: [String]) -> String? {
        let wanted = parts(detected)
        let candidates = supported.filter { parts($0).language == wanted.language && parts($0).script == wanted.script }
        return candidates.first { parts($0).region == wanted.region } ?? candidates.first
    }

    /// True for the same language in the same script, such as `en` and `en-GB`, so there is nothing to translate.
    public static func same(_ first: String, _ second: String) -> Bool {
        let one = parts(first), other = parts(second)
        return one.language == other.language && one.script == other.script
    }

    /// The identifier to name a language by, so that languages sharing a language code can be told apart:
    /// `en` is named as `en-US` beside `en-GB`, and `zh` as `zh-Hans` beside `zh-TW`.
    public static func displayIdentifier(_ code: String, among languages: [String]) -> String {
        let own = parts(code)
        let siblings = languages.filter { $0 != code && parts($0).language == own.language }
        guard let language = own.language, !siblings.isEmpty else { return code }
        if siblings.contains(where: { parts($0).script != own.script }), let script = own.script { return language + "-" + script }
        return own.region.map { language + "-" + $0 } ?? code
    }

    private static func parts(_ code: String) -> (language: String?, script: String?, region: String?) {
        let language = Locale.Language(identifier: Locale.Language(identifier: code).maximalIdentifier)
        return (language.languageCode?.identifier, language.script?.identifier, language.region?.identifier)
    }
}

/// Which lyric lines are translated, and how the results line up with them. Translations are shown under the lyrics
/// and never change them or the lyrics cache (R-LYR-6).
public enum LyricTranslationPlan {
    /// Lines worth translating: lines with letters that are not already in the target language.
    public static func lineIndices(_ lines: [String], isInTarget: (String) -> Bool) -> [Int] {
        lines.indices.filter { index in
            let line = lines[index]
            return line.unicodeScalars.contains { CharacterSet.letters.contains($0) } && !isInTarget(line)
        }
    }

    /// One translation per line from responses tagged with the line's index; other lines stay empty.
    public static func assemble(lineCount: Int, responses: [(id: String?, text: String)]) -> [String] {
        var result = Array(repeating: "", count: lineCount)
        for response in responses {
            guard let index = response.id.flatMap(Int.init), result.indices.contains(index) else { continue }
            result[index] = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}

/// Lyric translations for the last few songs, kept in memory only, so going back to a song does not translate it
/// again. Nothing is written to disk (R-LYR-6).
public struct TranslationMemory<Value: Sendable>: Sendable {
    public static var maximum: Int { 20 }

    private var entries: [String: Value] = [:]
    private var order: [String] = []

    public init() {}

    public subscript(key: String) -> Value? { entries[key] }

    public mutating func store(_ value: Value, for key: String) {
        entries[key] = value
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > Self.maximum { entries[order.removeFirst()] = nil }
    }
}
