import Testing
@testable import RirikuCore

@Suite("Panel display")
struct PanelDisplayTests {
    private let builtIn = DisplayCandidate(id: "built-in", hasNotch: true, isMain: false)
    private let external = DisplayCandidate(id: "external", hasNotch: false, isMain: true)

    @Test("Automatic placement prefers the display with a notch")
    func prefersNotch() {
        #expect(PanelDisplay.choose(preferred: nil, from: [external, builtIn]) == 1)
    }

    @Test("Without a notch, the main display is used, then the first one")
    func fallsBackToMain() {
        let other = DisplayCandidate(id: "other", hasNotch: false, isMain: false)
        #expect(PanelDisplay.choose(preferred: nil, from: [other, external]) == 1)
        #expect(PanelDisplay.choose(preferred: nil, from: [other]) == 0)
        #expect(PanelDisplay.choose(preferred: nil, from: []) == nil)
    }

    @Test("A chosen display wins while it is connected and falls back when it is not")
    func followsChoice() {
        #expect(PanelDisplay.choose(preferred: "external", from: [builtIn, external]) == 1)
        #expect(PanelDisplay.choose(preferred: "unplugged", from: [external, builtIn]) == 1)
    }
}

@Suite("Keyboard shortcut")
struct HotKeyTests {
    @Test("Needs Command, Option, or Control")
    func requiresModifier() {
        #expect(HotKey(keyCode: 45, modifiers: HotKey.command | HotKey.option, key: "N").isValid)
        #expect(HotKey(keyCode: 45, modifiers: HotKey.control, key: "N").isValid)
        #expect(!HotKey(keyCode: 45, modifiers: 0, key: "N").isValid, "a plain key would trigger while typing")
        #expect(!HotKey(keyCode: 45, modifiers: HotKey.shift, key: "N").isValid, "Shift alone types capitals")
        #expect(!HotKey(keyCode: 45, modifiers: HotKey.command, key: "").isValid)
    }

    @Test("Keeps only modifier flags and labels them in menu order")
    func labelsModifiers() {
        let all = HotKey(keyCode: 45, modifiers: HotKey.command | HotKey.shift | HotKey.option | HotKey.control | 1, key: "N")
        #expect(all.modifiers == HotKey.command | HotKey.shift | HotKey.option | HotKey.control)
        #expect(all.label == "⌃⌥⇧⌘N")
        #expect(HotKey(keyCode: 49, modifiers: HotKey.option, key: "␣").label == "⌥␣")
    }

    @Test("Names keys from the typed character or a symbol")
    func namesKeys() {
        #expect(HotKey.keyName(keyCode: 45, characters: "n") == "N")
        #expect(HotKey.keyName(keyCode: 49, characters: " ") == "␣")
        #expect(HotKey.keyName(keyCode: 96, characters: "\u{F708}") == "F5")
        #expect(HotKey.keyName(keyCode: 126, characters: "\u{F700}") == "↑")
        #expect(HotKey.keyName(keyCode: 200, characters: "\u{F710}") == nil, "an unknown function key has no label")
        #expect(HotKey.keyName(keyCode: 0, characters: nil) == nil)
    }
}
