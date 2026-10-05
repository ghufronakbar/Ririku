import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RirikuCore

/// The Tray tab: an AirDrop card and the files dropped on the panel.
struct TrayView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var tray: TrayStore
    @State private var airDropTargeted = false
    @State private var filesTargeted = false

    var body: some View {
        HStack(alignment: .top, spacing: PanelMetrics.widgetSpacing) {
            airDropCard.frame(width: PanelMetrics.minimumUnitWidth)
            files
        }
        .frame(height: ToolKind.tray.contentHeight)
        .onAppear { tray.refresh() }
    }

    private var airDropCard: some View {
        Button { tray.airDropAll() } label: {
            VStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 24, weight: .medium)).foregroundStyle(model.accent)
                Text(model.t("AirDrop")).font(.callout.weight(.semibold))
                Text(tray.items.isEmpty ? model.t("Drop files to send them.") : model.t("Drop files, or click to send the Tray."))
                    .font(.caption2).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(airDropTargeted ? model.accent.opacity(0.3) : Color.white.opacity(0.07)))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $airDropTargeted) { providers in
            TrayStore.fileURLs(from: providers) { tray.airDrop($0) }
            return true
        }
        .accessibilityLabel(model.t("Send with AirDrop"))
    }

    @ViewBuilder
    private var files: some View {
        let background = RoundedRectangle(cornerRadius: 14)
        Group {
            if tray.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 24, weight: .medium))
                    Text(model.t("Drop files here")).font(.callout.weight(.semibold))
                    Text(model.t("The Tray keeps a link to each file, never a copy.")).font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background.strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])).foregroundStyle(.white.opacity(0.25)))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(tray.items) { item in itemView(item) }
                    }
                    .padding(8)
                }
                .scrollIndicators(.never)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(background.fill(.white.opacity(0.07)))
                .overlay(alignment: .topTrailing) {
                    WidgetButton(icon: "xmark", label: model.t("Clear Tray"), size: 20) { tray.clear() }.padding(6)
                }
            }
        }
        .overlay(background.strokeBorder(model.accent, lineWidth: 2).opacity(filesTargeted ? 1 : 0))
        .onDrop(of: [.fileURL], isTargeted: $filesTargeted) { providers in
            TrayStore.fileURLs(from: providers) { tray.add($0) }
            return true
        }
    }

    private func itemView(_ item: TrayItem) -> some View {
        Button { tray.open(item) } label: {
            VStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.path)).resizable().frame(width: 40, height: 40)
                Text(item.name).font(.caption2).lineLimit(2).multilineTextAlignment(.center).frame(width: 68)
            }
            .frame(width: 72, height: 82, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.name)
        .onDrag { tray.dragProvider(item) }
        .contextMenu {
            Button(model.t("Open")) { tray.open(item) }
            Button(model.t("Show in Finder")) { tray.showInFinder(item) }
            Button(model.t("Send with AirDrop")) { tray.airDrop([tray.location(of: item)].compactMap { $0 }) }
            Divider()
            Button(model.t("Remove from Tray")) { tray.remove(item) }
        }
        .accessibilityLabel(model.t("Open %@", item.name))
        .accessibilityAction(named: model.t("Remove from Tray")) { tray.remove(item) }
    }
}
