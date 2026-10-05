import SwiftUI

/// The notch panel's surface: black, rounded at the bottom, opened by hover or a click.
/// It shows the compact music island, or the selected tab once expanded.
struct PanelView: View {
    @ObservedObject var model: AppModel
    var hoverChanged: (Bool) -> Void

    var body: some View {
        Group {
            if model.expanded {
                ExpandedPanelView(model: model, music: model.music, tab: model.currentTab) { model.selectedTabID = $0 }
            } else {
                MusicIslandView(model: model, music: model.music)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .background(.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: model.expanded ? 26 : 16, bottomTrailingRadius: model.expanded ? 26 : 16))
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
        .onTapGesture { model.expanded = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.t("Ririku, music player"))
        .environment(\.locale, model.locale)
    }
}
