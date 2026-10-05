import SwiftUI
import RirikuCore

/// The Clipboard tab: recent text and images, newest first. Clicking one puts it back on the clipboard.
struct ClipboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var clipboard: ClipboardStore
    @State private var copiedID: String?

    var body: some View {
        let background = RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.07))
        Group {
            if clipboard.entries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 24, weight: .medium))
                    Text(model.t("Nothing copied yet")).font(.callout.weight(.semibold))
                    Text(model.t("Text and images you copy appear here. Passwords marked as secret are skipped."))
                        .font(.caption2).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(clipboard.entries) { entry in row(entry) }
                    }
                    .padding(6)
                }
                .scrollIndicators(.never)
                .background(background)
            }
        }
        .frame(height: ToolKind.clipboard.contentHeight)
    }

    private func row(_ entry: ClipboardEntry) -> some View {
        HStack(spacing: 6) {
            Button { copy(entry) } label: {
                HStack(spacing: 8) {
                    if let image = clipboard.thumbnail(entry) {
                        Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 120, maxHeight: 36, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Text((entry.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 12)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 4)
                    if copiedID == entry.id {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(model.accent)
                    } else {
                        Text(entry.date.formatted(.relative(presentation: .named).locale(model.locale)))
                            .font(.caption2).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                    }
                }
                .padding(.vertical, 4).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.source.map { model.t("Copied from %@", $0) } ?? "")
            .accessibilityLabel(entry.kind == .image ? model.t("Image") : entry.text ?? "")
            .accessibilityHint(model.t("Puts it back on the clipboard"))
            WidgetButton(icon: "xmark", label: model.t("Delete"), size: 18) { clipboard.delete(entry) }
        }
        .contextMenu {
            Button(model.t("Copy")) { copy(entry) }
            Button(model.t("Delete"), role: .destructive) { clipboard.delete(entry) }
        }
    }

    private func copy(_ entry: ClipboardEntry) {
        clipboard.copy(entry)
        copiedID = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copiedID == entry.id { copiedID = nil } }
    }
}
