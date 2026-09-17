import Testing
@testable import RirikuCore

@Suite("LRC parsing")
struct LRCParserTests {
    @Test("Parses timestamps with and without fractions")
    func parsesTimestamps() {
        let lines = LRCParser.parse("[00:01]first\n[01:02.5]second\n[02:03.250]third\n")
        #expect(lines.map(\.text) == ["first", "second", "third"])
        #expect(lines[0].time == 1)
        #expect(lines[1].time == 62.5)
        #expect(abs(lines[2].time - 123.25) < 0.001)
    }

    @Test("Applies the LRC offset tag")
    func appliesOffsetTag() {
        let lines = LRCParser.parse("[offset:+500]\n[00:10]line\n")
        #expect(lines.first?.time == 9.5)
    }

    @Test("Never produces negative times")
    func clampsNegativeTimes() {
        let lines = LRCParser.parse("[offset:+5000]\n[00:01]line\n")
        #expect(lines.first?.time == 0)
    }

    @Test("Repeats a line for every timestamp on it")
    func expandsMultipleTimestamps() {
        let lines = LRCParser.parse("[00:05][00:20]chorus\n")
        #expect(lines.map(\.time) == [5, 20])
        #expect(lines.allSatisfy { $0.text == "chorus" })
    }

    @Test("Sorts by time and keeps the original order within the same timestamp")
    func sortsStably() {
        let lines = LRCParser.parse("[00:20]late\n[00:10]japanese\n[00:10]romaji\n")
        #expect(lines.map(\.text) == ["japanese", "romaji", "late"])
    }

    @Test("Ignores metadata and lines without a timestamp")
    func ignoresInvalidLines() {
        let lines = LRCParser.parse("[ti:Title]\nplain text\n[00:04]kept\n[xx:yy]broken\n")
        #expect(lines.map(\.text) == ["kept"])
    }

    @Test("Keeps empty lyrics as instrumental gaps")
    func keepsEmptyLines() {
        let lines = LRCParser.parse("[00:00]\n[00:30]sing\n")
        #expect(lines.count == 2)
        #expect(lines[0].text.isEmpty)
    }

    @Test("Selects the last line at or before the effective position")
    func selectsActiveLine() {
        let lines = LRCParser.parse("[00:00]a\n[00:10]b\n[00:20]c\n")
        #expect(LRCParser.activeIndex(in: lines, position: 0, offset: 0) == 0)
        #expect(LRCParser.activeIndex(in: lines, position: 9.9, offset: 0) == 0)
        #expect(LRCParser.activeIndex(in: lines, position: 10, offset: 0) == 1)
        #expect(LRCParser.activeIndex(in: lines, position: 999, offset: 0) == 2)
    }

    @Test("A positive offset delays lines and a negative one advances them")
    func appliesOffset() {
        let lines = LRCParser.parse("[00:00]a\n[00:10]b\n")
        #expect(LRCParser.activeIndex(in: lines, position: 10, offset: 2) == 0)
        #expect(LRCParser.activeIndex(in: lines, position: 9, offset: -2) == 1)
    }

    @Test("Has no active line before the first timestamp or without lyrics")
    func handlesEdges() {
        let lines = LRCParser.parse("[00:05]a\n")
        #expect(LRCParser.activeIndex(in: lines, position: 4, offset: 0) == nil)
        #expect(LRCParser.activeIndex(in: [], position: 10, offset: 0) == nil)
    }
}

@Suite("Japanese display preference")
struct JapaneseDisplayTests {
    private func lines(_ text: String) -> [LyricLine] { LRCParser.parse(text) }

    @Test("Hides a Latin line sharing a timestamp with Japanese")
    func hidesRomajiOnSharedTimestamp() {
        let display = LRCParser.displayLines(lines("[00:10]アイドル\n[00:10]aidoru\n"), preferJapanese: true)
        #expect(display.map(\.text) == ["アイドル"])
    }

    @Test("Keeps Latin lines at other timestamps")
    func keepsOtherTimestamps() {
        let display = LRCParser.displayLines(lines("[00:10]アイドル\n[00:12]English line\n"), preferJapanese: true)
        #expect(display.count == 2)
    }

    @Test("Keeps mixed Japanese and Latin text on a shared timestamp")
    func keepsMixedText() {
        let display = LRCParser.displayLines(lines("[00:10]夢を Dream\n[00:10]yume wo Dream\n"), preferJapanese: true)
        #expect(display.map(\.text) == ["夢を Dream"])
    }

    @Test("Leaves tracks without kana untouched")
    func requiresKana() {
        let source = lines("[00:10]漢字\n[00:10]kanji\n")
        #expect(LRCParser.displayLines(source, preferJapanese: true).count == 2)
    }

    @Test("Keeps Korean and Chinese lines on a shared timestamp")
    func keepsOtherScripts() {
        let display = LRCParser.displayLines(lines("[00:10]アイドル\n[00:10]아이돌\n[00:10]偶像\n"), preferJapanese: true)
        #expect(display.count == 3)
    }

    @Test("Returns every line when the preference is off")
    func returnsAllWhenDisabled() {
        let source = lines("[00:10]アイドル\n[00:10]aidoru\n")
        #expect(LRCParser.displayLines(source, preferJapanese: false).count == 2)
    }

    @Test("Keeps empty gap lines")
    func keepsGaps() {
        let display = LRCParser.displayLines(lines("[00:10]アイドル\n[00:10]\n"), preferJapanese: true)
        #expect(display.count == 2)
    }
}
