import AppKit
import CryptoKit
import RirikuCore

/// Clipboard history (D-020): off by default; while on, it watches the pasteboard, skips concealed, transient,
/// and generated content (R-WID-6), and keeps up to 50 text or image entries on this Mac only. Turning it off
/// stops watching and deletes the history. Contents are never logged (R-SEC-6).
@MainActor
final class ClipboardStore: ObservableObject {
    static let interval: TimeInterval = 0.5

    @Published private(set) var enabled: Bool
    @Published private(set) var entries: [ClipboardEntry] = []

    private let defaults: UserDefaults
    private let pasteboard: NSPasteboard
    /// Where the history and its images are kept: `~/Library/Application Support/Ririku/Clipboard`.
    let folder: URL
    private var timer: Timer?
    private var lastChangeCount: Int
    private var thumbnails: [String: NSImage] = [:]

    init(defaults: UserDefaults, pasteboard: NSPasteboard = .general, folder: URL? = nil) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ririku/Clipboard", isDirectory: true)
        enabled = defaults.bool(forKey: "clipboardHistory")
        lastChangeCount = pasteboard.changeCount
        if enabled {
            entries = ClipboardHistory.decode(try? Data(contentsOf: historyFile))
            startWatching()
        }
    }

    private var historyFile: URL { folder.appendingPathComponent("history.json") }

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        defaults.set(on, forKey: "clipboardHistory")
        if on {
            // Only what is copied from now on is kept, not what was already on the clipboard.
            lastChangeCount = pasteboard.changeCount
            startWatching()
        } else {
            timer?.invalidate()
            timer = nil
            clear()
        }
    }

    private func startWatching() {
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Reads the pasteboard if it changed since the last look. Called by the timer, and by tests.
    func poll(now: Date = Date()) {
        guard enabled, pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        let types = (pasteboard.types ?? []).map(\.rawValue)
        guard !ClipboardHistory.shouldSkip(types: types) else { return }
        let source = NSWorkspace.shared.frontmostApplication?.localizedName
        if let text = pasteboard.string(forType: .string) {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= ClipboardHistory.maximumTextLength else { return }
            add(ClipboardEntry(kind: .text, text: text, digest: Self.digest(Data(text.utf8)), date: now, source: source))
        } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
                  data.count <= ClipboardHistory.maximumImageBytes, let png = Self.png(data) {
            let digest = Self.digest(png)
            let name = UUID().uuidString + ".png"
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try png.write(to: folder.appendingPathComponent(name), options: .atomic)
            } catch { return }
            add(ClipboardEntry(kind: .image, imageFile: name, digest: digest, date: now, source: source))
        }
    }

    private func add(_ entry: ClipboardEntry) {
        let result = ClipboardHistory.adding(entry, to: entries)
        entries = result.entries
        deleteFiles(of: result.removed)
        save()
    }

    /// Puts an entry back on the clipboard and moves it to the top. Ririku cannot paste for you: that would need
    /// Accessibility permission (R-SEC-3).
    func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.kind {
        case .text: pasteboard.setString(entry.text ?? "", forType: .string)
        case .image:
            guard let data = try? Data(contentsOf: imageURL(entry)) else { return }
            pasteboard.setData(data, forType: .png)
        }
        // Writing changes the pasteboard too; this change is not a new entry.
        lastChangeCount = pasteboard.changeCount
        entries = [entry] + entries.filter { $0.id != entry.id }
        save()
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        deleteFiles(of: [entry])
        save()
    }

    /// Deletes every entry and the folder with the images.
    func clear() {
        entries = []
        thumbnails = [:]
        try? FileManager.default.removeItem(at: folder)
    }

    func imageURL(_ entry: ClipboardEntry) -> URL { folder.appendingPathComponent(entry.imageFile ?? "") }

    /// A small image for the list, kept in memory once read.
    func thumbnail(_ entry: ClipboardEntry) -> NSImage? {
        guard entry.kind == .image, let name = entry.imageFile else { return nil }
        if let cached = thumbnails[name] { return cached }
        guard let image = NSImage(contentsOf: imageURL(entry)) else { return nil }
        thumbnails[name] = image
        return image
    }

    private func save() {
        guard enabled else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(entries).write(to: historyFile, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyFile.path)
        } catch {}
    }

    private func deleteFiles(of removed: [ClipboardEntry]) {
        for entry in removed where entry.kind == .image {
            thumbnails[entry.imageFile ?? ""] = nil
            try? FileManager.default.removeItem(at: imageURL(entry))
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func png(_ data: Data) -> Data? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return data }
        return NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
    }
}
