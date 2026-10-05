import AppKit
import RirikuCore

/// The files on the Tray. It keeps references only and never moves, changes, or deletes a file (R-WID-7);
/// removing an item forgets it. File names are never logged (R-SEC-6).
@MainActor
final class TrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem]
    var notice: ((UIText, String) -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        items = TrayItems.decode(defaults.data(forKey: "trayItems"))
    }

    private func setItems(_ newItems: [TrayItem]) {
        items = newItems
        defaults.set(try? JSONEncoder().encode(items), forKey: "trayItems")
    }

    func add(_ urls: [URL]) {
        let new = urls.compactMap { url -> TrayItem? in
            let url = url.standardizedFileURL
            guard url.isFileURL, FileManager.default.fileExists(atPath: url.path),
                  let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return nil }
            return TrayItem(path: url.path, name: FileManager.default.displayName(atPath: url.path), bookmark: bookmark)
        }
        guard !new.isEmpty else { return }
        setItems(TrayItems.adding(new, to: items))
    }

    func remove(_ item: TrayItem) { setItems(items.filter { $0.id != item.id }) }

    /// Empties the Tray; the files themselves stay where they are.
    func clear() { setItems([]) }

    /// Where the file is now, or nil when it is gone.
    func location(of item: TrayItem) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil,
                                 bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Forgets files that no longer exist and follows the ones that moved or were renamed. Called when the Tray appears.
    func refresh() {
        var changed = false
        let updated = items.compactMap { item -> TrayItem? in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil,
                                     bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: url.path) else {
                changed = true
                return nil
            }
            guard stale || url.path != item.path else { return item }
            changed = true
            var moved = item
            moved.path = url.path
            moved.name = FileManager.default.displayName(atPath: url.path)
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) { moved.bookmark = fresh }
            return moved
        }
        if changed { setItems(updated) }
    }

    func open(_ item: TrayItem) {
        guard let url = location(of: item) else { refresh(); return }
        NSWorkspace.shared.open(url)
    }

    func showInFinder(_ item: TrayItem) {
        guard let url = location(of: item) else { refresh(); return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// The file for dragging out of the Tray; the drop target decides what to do with it.
    func dragProvider(_ item: TrayItem) -> NSItemProvider {
        guard let url = location(of: item) else { return NSItemProvider() }
        return NSItemProvider(object: url as NSURL)
    }

    /// Opens the AirDrop sheet for these files.
    func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            notice?(UIText("AirDrop is not available."), "exclamationmark.triangle")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    func airDropAll() { airDrop(items.compactMap(location(of:))) }

    /// File addresses from a drop, delivered on the main thread.
    nonisolated static func fileURLs(from providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        final class Collected: @unchecked Sendable {
            let lock = NSLock()
            var urls: [URL] = []
        }
        let collected = Collected()
        let group = DispatchGroup()
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    collected.lock.lock()
                    collected.urls.append(url)
                    collected.lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { MainActor.assumeIsolated { completion(collected.urls) } }
    }
}
