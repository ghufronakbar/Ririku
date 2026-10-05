import SwiftUI
import RirikuCore

/// Tools that fill a tab of their own. The raw value is the tab `kind` stored in the layout.
enum ToolKind: String, CaseIterable {
    case tray, clipboard

    static let identifiers = Set(allCases.map(\.rawValue))

    /// A tool needs the room of three small widgets.
    static let minimumContentWidth = PageGeometry.minimumWidth(units: [1, 1, 1], unit: PanelMetrics.minimumUnitWidth,
                                                               spacing: PanelMetrics.widgetSpacing)

    var contentHeight: Double {
        switch self {
        case .tray: return WidgetCardLayout.height
        case .clipboard: return 160
        }
    }

    @MainActor
    func title(_ model: AppModel) -> String {
        switch self {
        case .tray: return model.t("Tray")
        case .clipboard: return model.t("Clipboard")
        }
    }
}

/// Draws a tool tab.
struct ToolView: View {
    @ObservedObject var model: AppModel
    let kind: ToolKind

    var body: some View {
        switch kind {
        case .tray: TrayView(model: model, tray: model.tray)
        case .clipboard: ClipboardView(model: model, clipboard: model.clipboard)
        }
    }
}
