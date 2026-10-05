import AppKit
import SwiftUI
import RirikuCore

// Launchers open only what the user picked in Setup → Widgets (R-WID-9, R-WID-11).

struct AppsWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore

    var body: some View {
        let apps = widgets.data.apps
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t("Apps")).widgetCaption()
            if apps.isEmpty {
                Spacer(minLength: 0)
                Text(model.t("Choose apps in Setup → Widgets.")).font(.caption).foregroundStyle(.white.opacity(0.6))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34, maximum: 40), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(apps) { app in
                        Button { widgets.launch(app) } label: {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: widgets.appURL(app).path)).resizable().frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(app.name)
                        .accessibilityLabel(model.t("Open %@", app.name))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetCard()
    }
}

struct ShortcutsWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore

    var body: some View {
        LauncherList(model: model, title: model.t("Shortcuts"), icon: "command.square",
                     items: widgets.data.shortcuts.map { ($0, $0) }, empty: model.t("Choose shortcuts in Setup → Widgets."),
                     accessibility: { model.t("Run %@", $0) }) { name in widgets.runShortcut(name) }
    }
}

struct BookmarksWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore

    var body: some View {
        let bookmarks = widgets.data.bookmarks
        LauncherList(model: model, title: model.t("Bookmarks"), icon: "link",
                     items: bookmarks.map { ($0.id, $0.title) }, empty: model.t("Add bookmarks in Setup → Widgets."),
                     accessibility: { model.t("Open %@", $0) }) { id in
            if let bookmark = bookmarks.first(where: { $0.id == id }) { widgets.open(bookmark) }
        }
    }
}

/// A scrolling list of buttons, one per item, for the Shortcuts and Bookmarks widgets.
private struct LauncherList: View {
    @ObservedObject var model: AppModel
    let title: String
    let icon: String
    let items: [(id: String, name: String)]
    let empty: String
    let accessibility: (String) -> String
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).widgetCaption()
            if items.isEmpty {
                Spacer(minLength: 0)
                Text(empty).font(.caption).foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items, id: \.id) { item in
                            Button { action(item.id) } label: {
                                Label(item.name, systemImage: icon)
                                    .font(.system(size: 12)).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 3).padding(.horizontal, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06)))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(item.name)
                            .accessibilityLabel(accessibility(item.name))
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            Spacer(minLength: 0)
        }
        .widgetCard()
    }
}
