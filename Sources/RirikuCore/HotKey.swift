import Foundation

/// A global keyboard shortcut: a virtual key code and Carbon modifier flags, plus the key's label from when it was recorded.
public struct HotKey: Codable, Equatable, Sendable {
    // Carbon modifier flags (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`), kept here so the core needs no Carbon import.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    public let keyCode: UInt32
    public let modifiers: UInt32
    public let key: String

    public init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers & (Self.command | Self.shift | Self.option | Self.control)
        self.key = key
    }

    /// Command, Option, or Control is required, so ordinary typing can never trigger the shortcut.
    public var isValid: Bool {
        modifiers & (Self.command | Self.option | Self.control) != 0 && !key.isEmpty && key.count <= 3 && keyCode < 128
    }

    /// Modifier symbols in the order macOS menus use, then the key: "⌃⌥⇧⌘N".
    public var label: String {
        let symbols: [(UInt32, String)] = [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
        return symbols.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + key
    }

    /// The label for a key: a symbol or name for keys that type no visible character, otherwise the typed character.
    public static func keyName(keyCode: UInt32, characters: String?) -> String? {
        if let name = specialKeys[keyCode] { return name }
        guard let text = characters?.uppercased(), text.count == 1, let scalar = text.unicodeScalars.first,
              !CharacterSet.whitespacesAndNewlines.contains(scalar), !CharacterSet.controlCharacters.contains(scalar),
              // Function and arrow keys report characters in the private use area.
              !(0xF700...0xF8FF).contains(scalar.value) else { return nil }
        return text
    }

    private static let specialKeys: [UInt32: String] = [
        49: "␣", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
}
