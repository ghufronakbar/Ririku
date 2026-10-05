import Foundation

/// A file or folder the user dropped on the Tray. It is a reference, never a copy: the bookmark follows the file
/// when it is moved or renamed, and the original is never moved, changed, or deleted (R-WID-7).
public struct TrayItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// Where the file was when it was added or last found, used to recognize the same file again.
    public var path: String
    public var name: String
    public var bookmark: Data

    public init(id: String = UUID().uuidString, path: String, name: String, bookmark: Data) {
        self.id = id
        self.path = path
        self.name = name
        self.bookmark = bookmark
    }
}

public enum TrayItems {
    public static let maximum = 50

    /// New items go first; a file already in the tray moves to the front instead of appearing twice,
    /// and only the newest `maximum` items stay.
    public static func adding(_ new: [TrayItem], to items: [TrayItem]) -> [TrayItem] {
        var seen = Set<String>()
        var result: [TrayItem] = []
        for item in new + items where seen.insert(item.path).inserted {
            result.append(item)
        }
        return Array(result.prefix(maximum))
    }

    /// Reads stored items, skipping entries that cannot be read (R-COMPAT-3).
    public static func decode(_ data: Data?) -> [TrayItem] {
        guard let data, let list = try? JSONDecoder().decode([Lossy<TrayItem>].self, from: data) else { return [] }
        return Array(list.compactMap(\.value).prefix(maximum))
    }
}
