import SwiftUI
import UniformTypeIdentifiers

/// The notch panel's surface: black, rounded at the bottom, opened by hover or a click.
/// It shows the compact island, or the selected tab once expanded. It always uses the dark appearance,
/// so text fields and controls stay readable on black.
struct PanelView: View {
    @ObservedObject var model: AppModel
    var hoverChanged: (Bool) -> Void
    @State private var fileDragInside = false

    var body: some View {
        Group {
            if model.expanded {
                ExpandedPanelView(model: model, music: model.music, tab: model.currentTab) { model.selectedTabID = $0 }
            } else {
                CompactPanelView(model: model, music: model.music, widgets: model.widgets)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .background(.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: model.expanded ? 26 : 16, bottomTrailingRadius: model.expanded ? 26 : 16))
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
        .onTapGesture { model.expanded = true }
        // A file dragged onto the notch opens the Tray, and dropping it anywhere on the panel adds it there.
        .onDrop(of: [.fileURL], isTargeted: $fileDragInside) { providers in
            guard model.trayTab != nil else { return false }
            TrayStore.fileURLs(from: providers) { model.tray.add($0) }
            return true
        }
        .onChange(of: fileDragInside) { _, inside in if inside && model.trayTab != nil { model.fileDragEntered?() } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.t("Ririku, music player"))
        .environment(\.locale, model.locale)
        .environment(\.colorScheme, .dark)
    }
}
