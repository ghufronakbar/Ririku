import SwiftUI
import RirikuCore

/// The widgets this version can show. The raw value is the `kind` stored in the layout.
enum WidgetKind: String, CaseIterable {
    case music, system

    static let identifiers = Set(allCases.map(\.rawValue))

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .system: return "cpu"
        }
    }

    @MainActor
    func title(_ model: AppModel) -> String {
        switch self {
        case .music: return model.t("Music")
        case .system: return model.t("System")
        }
    }
}

/// Draws one widget of a page at the width the page gives it.
struct WidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    let slot: WidgetSlot
    let layout: ExpandedPanelLayout

    var body: some View {
        switch WidgetKind(rawValue: slot.kind) {
        case .music:
            if slot.wide {
                MusicWidgetView(model: model, music: music, lyricHeight: layout.lyricHeight, twoRows: layout.twoLyricRows)
            } else {
                MusicSmallWidgetView(model: model, music: music)
            }
        case .system: SystemWidgetView(model: model, monitor: model.system, wide: slot.wide)
        case nil: EmptyView()
        }
    }
}
