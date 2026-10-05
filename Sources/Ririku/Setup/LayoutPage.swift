import SwiftUI
import RirikuCore

/// Edits the panel's tabs and widgets (D-018). A live preview of the expanded panel stays above the editor.
struct LayoutPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    @State private var previewTabID: String?

    private static let previewWidth: Double = 460

    var body: some View {
        VStack(spacing: 0) {
            // Outside the form, so its row styling does not reach the panel's controls.
            VStack(spacing: 8) {
                preview
                Text(model.t("The preview is live: the music and system widgets show what the panel shows. Click a tab icon to preview another page."))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.t("Preview of the expanded panel"))
            Divider()
            Form {
                ForEach(model.layout.tabs) { tab in
                    Section { if tab.isPage { pageEditor(tab) } else { toolEditor(tab) } } header: { pageHeader(tab) }
                }
                Section {
                    HStack {
                        Button(model.t("Add Page")) {
                            var added: String?
                            model.editLayout { added = $0.addPage() }
                            if let added { previewTabID = added }
                        }
                        .disabled(model.layout.tabs.count >= PanelLayout.maximumTabs)
                        Spacer()
                        Button(model.t("Reset to Default Layout")) { model.resetLayout(); previewTabID = nil }
                    }
                    Text(model.t("Each widget can be on one page. A small widget takes one unit and a wide widget two; a page that needs more room than the expanded island width opens wider, up to the width of the screen."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Preview

    private var previewTab: PanelTab {
        model.visibleTabs.first { $0.id == previewTabID } ?? model.visibleTabs.first ?? PanelLayout.standard.tabs[0]
    }

    private var preview: some View {
        let tab = previewTab
        let size = model.expandedLayout(for: tab, screenWidth: model.screenWidth)
        let scale = min(1, Self.previewWidth / size.width)
        return ExpandedPanelView(model: model, music: music, tab: tab) { previewTabID = $0 }
            .frame(width: size.width, height: size.height, alignment: .top)
            .foregroundStyle(.white)
            .background(.black)
            .overlay(alignment: .top) {
                // Where the hardware notch hides the panel, so nothing important is placed there (R-UI-5).
                UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                    .fill(Color(white: 0.16))
                    .frame(width: model.notchWidth, height: model.topHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
            .environment(\.colorScheme, .dark)
            .environment(\.panelPreview, true)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
    }

    // MARK: Editor

    private func pageHeader(_ tab: PanelTab) -> some View {
        HStack {
            Text(model.tabName(tab))
            Spacer()
            Menu {
                Button(model.t("Move Left")) { model.editLayout { $0.moveTab(id: tab.id, by: -1) } }
                    .disabled(model.layout.tabs.first?.id == tab.id)
                Button(model.t("Move Right")) { model.editLayout { $0.moveTab(id: tab.id, by: 1) } }
                    .disabled(model.layout.tabs.last?.id == tab.id)
                if tab.isPage {
                    Divider()
                    Button(model.t("Delete Page"), role: .destructive) { model.editLayout { $0.removeTab(id: tab.id) } }
                        .disabled(model.visibleTabs.count <= 1)
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(model.t("Page actions"))
        }
    }

    /// A tool cannot be deleted, only hidden; it keeps its contents while hidden.
    @ViewBuilder
    private func toolEditor(_ tab: PanelTab) -> some View {
        Toggle(model.t("Show in the panel"), isOn: Binding(get: { !tab.hidden }, set: { shown in
            model.editLayout { $0.setHidden(!shown, forTab: tab.id) }
        }))
        .disabled(!tab.hidden && model.visibleTabs.count <= 1)
        Text(model.t("A tool fills its tab. Settings for it are in Setup → Widgets."))
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func pageEditor(_ tab: PanelTab) -> some View {
        TextField(model.t("Page name"), text: Binding(get: { tab.name }, set: { name in model.editLayout { $0.renameTab(id: tab.id, to: name) } }),
                  prompt: Text(model.tabName(PanelTab(id: tab.id, icon: tab.icon))))
        Picker(model.t("Icon"), selection: Binding(get: { tab.icon }, set: { icon in model.editLayout { $0.setIcon(icon, forTab: tab.id) } })) {
            ForEach(PanelLayout.pageIcons, id: \.self) { icon in
                Image(systemName: icon).tag(icon)
            }
        }
        ForEach(tab.widgets) { slot in widgetRow(slot, in: tab) }
            .onMove { offsets, destination in model.editLayout { $0.moveWidgets(inTab: tab.id, from: offsets, to: destination) } }
        let unused = model.layout.unusedKinds(of: WidgetKind.allCases.map(\.rawValue)).compactMap(WidgetKind.init(rawValue:))
        Menu(model.t("Add Widget")) {
            ForEach(unused, id: \.self) { kind in
                Button { model.addWidget(kind, toTab: tab.id) } label: {
                    Label(kind.title(model), systemImage: kind.icon)
                }
            }
        }
        .disabled(unused.isEmpty)
        .fixedSize()
    }

    private func widgetRow(_ slot: WidgetSlot, in tab: PanelTab) -> some View {
        let kind = WidgetKind(rawValue: slot.kind)
        let others = model.layout.tabs.filter { $0.id != tab.id && $0.isPage }
        return HStack {
            Image(systemName: kind?.icon ?? "questionmark.square").frame(width: 20).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(kind?.title(model) ?? slot.kind)
            Spacer()
            Picker(model.t("Size"), selection: Binding(get: { slot.wide }, set: { wide in model.editLayout { $0.setWide(wide, forWidget: slot.id) } })) {
                Text(model.t("Small")).tag(false)
                Text(model.t("Wide")).tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            Menu {
                Button(model.t("Move Left")) { model.editLayout { $0.moveWidget(id: slot.id, by: -1) } }
                    .disabled(tab.widgets.first?.id == slot.id)
                Button(model.t("Move Right")) { model.editLayout { $0.moveWidget(id: slot.id, by: 1) } }
                    .disabled(tab.widgets.last?.id == slot.id)
                if !others.isEmpty {
                    Menu(model.t("Move to Page")) {
                        ForEach(others) { other in
                            Button(model.tabName(other)) { model.editLayout { $0.moveWidget(id: slot.id, toTab: other.id) } }
                        }
                    }
                }
                Divider()
                Button(model.t("Remove Widget"), role: .destructive) { model.editLayout { $0.removeWidget(id: slot.id) } }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(model.t("Widget actions"))
        }
    }
}
