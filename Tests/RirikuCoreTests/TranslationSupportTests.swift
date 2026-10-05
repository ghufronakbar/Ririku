import Foundation
import Testing
@testable import RirikuCore

/// The languages macOS 15.7 offered for translation on 2026-10-05.
private let supported = ["vi", "pt", "uk", "it", "zh-TW", "ko", "en-GB", "de", "zh", "ja", "id", "nl", "fr", "th", "es", "tr",
                         "pl", "ar-AE", "ru", "en", "hi"]

@Suite("Translation support")
struct TranslationSupportTests {
    @Test("Detected languages map to the languages translation offers")
    func matchesLanguages() {
        #expect(TranslationLanguage.match("ja", in: supported) == "ja")
        #expect(TranslationLanguage.match("en", in: supported) == "en", "the United States region comes first for English")
        #expect(TranslationLanguage.match("zh-Hans", in: supported) == "zh")
        #expect(TranslationLanguage.match("zh-Hant", in: supported) == "zh-TW")
        #expect(TranslationLanguage.match("sw", in: supported) == nil)
    }

    @Test("The same language in another region needs no translation; another script does")
    func comparesLanguages() {
        #expect(TranslationLanguage.same("en", "en-GB"))
        #expect(TranslationLanguage.same("ja", "ja-JP"))
        #expect(!TranslationLanguage.same("zh", "zh-TW"))
        #expect(!TranslationLanguage.same("ja", "en"))
    }

    @Test("Languages that share a language code are named apart")
    func namesLanguages() {
        #expect(TranslationLanguage.displayIdentifier("ja", among: supported) == "ja")
        #expect(TranslationLanguage.displayIdentifier("en", among: supported) == "en-US")
        #expect(TranslationLanguage.displayIdentifier("en-GB", among: supported) == "en-GB")
        #expect(TranslationLanguage.displayIdentifier("zh", among: supported) == "zh-Hans")
        #expect(TranslationLanguage.displayIdentifier("zh-TW", among: supported) == "zh-Hant")
    }

    @Test("Only lines with letters that are not in the target language are translated")
    func choosesLines() {
        let lines = ["君の名前", "", "♪", "I love you", "夜の街で 123"]
        let indices = LyricTranslationPlan.lineIndices(lines) { $0 == "I love you" }
        #expect(indices == [0, 4])
    }

    @Test("A line counts as already translated only when detection agrees and its letters fit the target's alphabet")
    func recognizesTargetLines() {
        #expect(LyricTranslationPlan.isInTarget("I love you", source: "ja", target: "en", targetShare: 1))
        #expect(!LyricTranslationPlan.isInTarget("사랑해 baby", source: "ko", target: "en", targetShare: 1), "a mixed line is translated")
        #expect(!LyricTranslationPlan.isInTarget("君の名前", source: "ja", target: "en", targetShare: 0))
        #expect(LyricTranslationPlan.isInTarget("君の名前", source: "en", target: "ja", targetShare: 1))
        #expect(!LyricTranslationPlan.isInTarget("Baby 君の名前", source: "en", target: "ja", targetShare: 1))
        #expect(LyricTranslationPlan.isInTarget("I miss you", source: "id", target: "en", targetShare: 0.99))
        #expect(!LyricTranslationPlan.isInTarget("Aku rindu kamu", source: "id", target: "en", targetShare: 0))
        #expect(!LyricTranslationPlan.isInTarget("Hello", source: "id", target: "en", targetShare: 0.6), "an unsure line is translated")
    }

    @Test("Language detection codes keep the Chinese script and drop regions")
    func recognizerCodes() {
        #expect(TranslationLanguage.recognizerCode("zh") == "zh-Hans")
        #expect(TranslationLanguage.recognizerCode("zh-TW") == "zh-Hant")
        #expect(TranslationLanguage.recognizerCode("en-GB") == "en")
        #expect(TranslationLanguage.recognizerCode("ja") == "ja")
        #expect(TranslationLanguage.usesLatin("id") && !TranslationLanguage.usesLatin("ko"))
    }

    @Test("Translations line up with their lines, and unknown or stray responses are ignored")
    func assemblesResults() {
        let result = LyricTranslationPlan.assemble(lineCount: 4, responses: [("0", " Your name "), ("3", "In the night"), (nil, "x"), ("9", "y")])
        #expect(result == ["Your name", "", "", "In the night"])
    }

    @Test("Keeps the translations of the last songs only")
    func remembersRecentSongs() {
        var memory = TranslationMemory<[String]>()
        for number in 0...TranslationMemory<[String]>.maximum { memory.store(["\(number)"], for: "song \(number)") }
        #expect(memory["song 0"] == nil, "the oldest song is forgotten")
        #expect(memory["song 1"] == ["1"])
        memory.store(["again"], for: "song 1")
        memory.store(["new"], for: "song new")
        #expect(memory["song 1"] == ["again"], "a song used again stays")
        #expect(memory["song 2"] == nil)
    }
}
