/// A connected display as the panel placement sees it.
public struct DisplayCandidate: Equatable, Sendable {
    public let id: String
    public let hasNotch: Bool
    public let isMain: Bool

    public init(id: String, hasNotch: Bool, isMain: Bool) {
        self.id = id
        self.hasNotch = hasNotch
        self.isMain = isMain
    }
}

public enum PanelDisplay {
    /// The display for the panel: the one chosen in Setup while it is connected, otherwise the first display
    /// with a notch, otherwise the main display. `nil` only when no display is connected.
    public static func choose(preferred: String?, from displays: [DisplayCandidate]) -> Int? {
        if let preferred, let index = displays.firstIndex(where: { $0.id == preferred }) { return index }
        if let index = displays.firstIndex(where: \.hasNotch) { return index }
        return displays.firstIndex(where: \.isMain) ?? displays.indices.first
    }
}
