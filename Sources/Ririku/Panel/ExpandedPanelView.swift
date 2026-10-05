import SwiftUI
import RirikuCore

/// The expanded panel for one tab: the tab bar left of the notch and the Setup button right of it,
/// then the page's widgets in a row. Setup's Layout page draws the same view as its preview.
struct ExpandedPanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    let tab: PanelTab
    var selectTab: (String) -> Void

    var body: some View {
        let layout = model.expandedLayout(for: tab, screenWidth: model.screenWidth)
        VStack(spacing: 0) {
            HStack(spacing: PanelMetrics.tabSpacing) {
                if layout.showsTabs {
                    ForEach(model.visibleTabs) { item in tabButton(item) }
                }
                Spacer(minLength: 0)
                Button { model.openSetup?() } label: {
                    Image(systemName: "gearshape").frame(width: PanelMetrics.gearWidth, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(model.t("Open Setup")).accessibilityLabel(model.t("Open Setup window"))
            }
            .padding(.horizontal, PanelMetrics.stripPadding)
            .frame(height: model.islandHeight)
            HStack(alignment: .top, spacing: PanelMetrics.widgetSpacing) {
                if let tool = ToolKind(rawValue: tab.kind) {
                    ToolView(model: model, kind: tool)
                } else if tab.widgets.isEmpty {
                    Text(model.t("No widgets on this page. Add them in Setup → Layout."))
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: PanelMetrics.emptyPageHeight)
                }
                ForEach(tab.widgets) { slot in
                    WidgetView(model: model, music: music, slot: slot, layout: layout)
                        .frame(width: layout.slotWidths[slot.id] ?? 0, alignment: .top)
                }
            }
            .padding(.horizontal, ExpandedLayout.horizontalPadding)
            .padding(.top, ExpandedLayout.topPadding).padding(.bottom, ExpandedLayout.bottomPadding)
        }
    }

    private func tabButton(_ item: PanelTab) -> some View {
        let selected = item.id == tab.id
        let name = model.tabName(item)
        return Button { selectTab(item.id) } label: {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: PanelMetrics.tabButtonWidth, height: 24)
                .foregroundStyle(selected ? .white : .white.opacity(0.55))
                // The selected tab has a filled background, not only a brighter icon (R-UI-15).
                .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.white.opacity(0.18) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
