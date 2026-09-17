import AppKit
import SwiftUI
import UniformTypeIdentifiers
import NotchCore

struct PlaybackSession {
    var snapshot: PlaybackSnapshot
    var receivedAt: TimeInterval
    var id: String { snapshot.sessionId + ":" + snapshot.sourceId }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var sessions: [String: PlaybackSession] = [:]
    @Published var selectedSource = "" {
        didSet {
            commandError = nil
            pendingCommand = nil
            if !automaticSource { preferredTab = sessions[selectedSource]?.snapshot.sourceId ?? preferredTab }
            refreshMedia()
            geometryChanged?()
        }
    }
    @Published var automaticSource: Bool {
        didSet {
            preferredTab = current?.snapshot.sourceId
            save()
            reconcileSource()
        }
    }
    @Published var automaticLyrics: Bool {
        didSet {
            save()
            lyricTask?.cancel()
            lyricRequestID = nil
            if !automaticLyrics, let key = trackKey, currentLines.isEmpty { lyricMessages[key] = "Lirik otomatis nonaktif" }
            refreshMedia()
        }
    }
    @Published var expanded = false { didSet { geometryChanged?() } }
    @Published var panelWidth: Double { didSet { save(); geometryChanged?() } }
    @Published var accentName: String { didSet { save() } }
    @Published var animations: Bool { didSet { save() } }
    @Published var showLyrics: Bool { didSet { save(); geometryChanged?() } }
    @Published var lyricSource: String {
        didSet {
            save()
            lyricTask?.cancel()
            lyricRequestID = nil
            if lyricSource == "caption" { cancelLyricSearch() }
            refreshMedia()
        }
    }
    @Published private var lyricOffsets: [String: Double]
    @Published var lyricCandidates: [LyricsRecord] = []
    @Published var lyricSearchStatus = ""
    @Published var lyricSearchBusy = false
    private var searchTask: Task<Void, Never>?
    private var searchToken = UUID()
    private var candidateTrackKey: String?
    private var candidateDuration: Double?

    var lyricOffset: Double {
        get { trackKey.flatMap { lyricOffsets[$0] } ?? 0 }
        set {
            guard let key = trackKey, newValue.isFinite else { return }
            lyricOffsets[key] = min(60, max(-60, newValue))
            defaults.set(lyricOffsets, forKey: "lyricOffsetsByTrack")
        }
    }
    @Published var demo = false { didSet { configureDemo() } }
    @Published var lyrics: [String: [LyricLine]] = [:]
    @Published var lyricNames: [String: String] = [:]
    @Published var lyricMessages: [String: String] = [:]
    @Published var plainLyrics: [String: String] = [:]
    @Published var artwork: NSImage?
    @Published var commandError: String? { didSet { geometryChanged?() } }
    @Published var bridgeError: String?
    @Published var pendingCommand: String?
    @Published var notchWidth: CGFloat = 180
    @Published var topHeight: CGFloat = 34
    var geometryChanged: (() -> Void)?
    var trackChanged: (() -> Void)?
    var openSetup: (() -> Void)?
    var sendPacket: ((Data) -> Void)?
    private var timer: Timer?
    private let defaults: UserDefaults
    private var lastTrackKey: String?
    private var preferredTab: String?
    private let lyricsService: LyricsService
    private let artworkService = ArtworkService()
    private var lyricTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var lyricRequestID: String?
    private var artworkRequestID: String?
    private var manualLyrics = Set<String>()
    private var resolvedQueries: [String: LyricsQuery] = [:]
    private var lyricRetryAfter = Date.distantFuture
    private var artworkRetryAfter = Date.distantFuture

    init(lyricsService: LyricsService = LyricsService(), defaults: UserDefaults = .standard) {
        self.lyricsService = lyricsService
        self.defaults = defaults
        automaticSource = defaults.object(forKey: "automaticSource") as? Bool ?? true
        automaticLyrics = defaults.object(forKey: "automaticLyrics") as? Bool ?? true
        let storedWidth = defaults.double(forKey: "panelWidth")
        panelWidth = [398.0, 442, 480].contains(storedWidth) ? storedWidth : 442
        accentName = defaults.string(forKey: "accentName") ?? "Peach"
        animations = defaults.object(forKey: "animations") as? Bool ?? true
        showLyrics = defaults.object(forKey: "showLyrics") as? Bool ?? true
        let storedSource = defaults.string(forKey: "lyricSource") ?? "auto"
        lyricSource = ["auto", "lrclib", "caption"].contains(storedSource) ? storedSource : "auto"
        lyricOffsets = (defaults.dictionary(forKey: "lyricOffsetsByTrack") as? [String: Double] ?? [:]).filter { $0.value.isFinite && abs($0.value) <= 60 }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.expireSessions() }
        }
    }

    var current: PlaybackSession? {
        if demo { return sessions["demo:demo"] }
        guard let session = sessions[selectedSource],
              ProcessInfo.processInfo.systemUptime - session.receivedAt < 5 else { return nil }
        return session
    }

    var trackKey: String? {
        guard let snapshot = current?.snapshot, !snapshot.isAdvertisement else { return nil }
        return (snapshot.sourceLabel.hasPrefix("YouTube") ? "YouTube" : snapshot.sourceLabel) + ":" + snapshot.trackId
    }

    var accent: Color {
        switch accentName {
        case "Lavender": return Color(red: 0.78, green: 0.75, blue: 1)
        case "Netral": return .white
        default: return Color(red: 0.96, green: 0.78, blue: 0.7)
        }
    }

    var canAnimate: Bool { animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var usesVideoCaption: Bool {
        lyricSource != "lrclib" && (lyricSource == "caption" || currentLines.isEmpty)
            && current?.snapshot.captionEnabled == true && current?.snapshot.isAdvertisement == false
    }
    var currentLines: [LyricLine] { lyricSource == "caption" ? [] : (trackKey.flatMap { lyrics[$0] } ?? []) }
    var currentPlainLyrics: String? { lyricSource == "caption" ? nil : trackKey.flatMap { plainLyrics[$0] } }
    var canControl: Bool { current != nil && current?.snapshot.isAdvertisement == false && pendingCommand == nil }

    func position() -> Double {
        guard let current else { return 0 }
        return current.snapshot.position(at: ProcessInfo.processInfo.systemUptime, receivedAt: current.receivedAt, staleAfter: demo ? .greatestFiniteMagnitude : 5)
    }

    func lyricIndex() -> Int? {
        if usesVideoCaption { return nil }
        return LRCParser.activeIndex(in: currentLines, position: position(), offset: lyricOffset)
    }

    var lyricStatus: String {
        guard let current else { return "Menunggu musik di Chrome" }
        if current.snapshot.isAdvertisement { return "Iklan · lirik dihentikan" }
        if usesVideoCaption {
            let caption = current.snapshot.captionText ?? ""
            return caption.isEmpty ? "♪" : caption
        }
        if lyricSource == "caption" { return "Caption tidak tersedia · aktifkan CC atau pilih LRCLIB" }
        if currentLines.isEmpty {
            if let key = trackKey { return lyricMessages[key] ?? (automaticLyrics ? "Mencari lirik…" : "Lirik otomatis nonaktif") }
            return "Lirik belum tersedia"
        }
        guard let index = lyricIndex() else { return "♪" }
        return currentLines[index].text.isEmpty ? "♪" : currentLines[index].text
    }

    func receive(_ data: Data) {
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["protocolVersion"] as? Int == 1 else { return }
        if envelope["kind"] as? String == "openSetup" { openSetup?(); return }
        if envelope["kind"] as? String == "ack" {
            guard let commandId = envelope["commandId"] as? String, commandId == pendingCommand else { return }
            pendingCommand = nil
            if envelope["ok"] as? Bool != true { commandError = "Kontrol gagal. Coba kembali dari tab pemutar." }
            return
        }
        if envelope["kind"] as? String == "remove", let source = envelope["sourceId"] as? String,
           let session = envelope["sessionId"] as? String {
            sessions.removeValue(forKey: session + ":" + source)
            reconcileSource()
            refreshMedia()
            geometryChanged?()
            return
        }
        guard let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data), snapshot.isValid else { return }
        let entry = PlaybackSession(snapshot: snapshot, receivedAt: ProcessInfo.processInfo.systemUptime)
        if let previous = sessions[entry.id], snapshot.sequence <= previous.snapshot.sequence { return }
        let beganPlaying = snapshot.state == "playing" && !snapshot.isAdvertisement
            && (sessions[entry.id]?.snapshot.state != "playing" || sessions[entry.id]?.snapshot.isAdvertisement == true)
        let wasEmpty = current == nil
        sessions[entry.id] = entry
        reconcileSource(incomingID: entry.id, beganPlaying: beganPlaying)
        refreshMedia()
        if !demo && current?.id == entry.id {
            let key = snapshot.isAdvertisement ? nil : trackKey
            if lastTrackKey != key {
                let notify = lastTrackKey != nil && key != nil
                lastTrackKey = key
                commandError = nil
                pendingCommand = nil
                if notify { trackChanged?() }
            }
        }
        if wasEmpty != (current == nil) { geometryChanged?() }
    }

    func disconnect() {
        sessions = sessions.filter { $0.key == "demo:demo" }
        pendingCommand = nil
        refreshMedia()
        geometryChanged?()
    }

    private func expireSessions() {
        let now = ProcessInfo.processInfo.systemUptime
        let oldCount = sessions.count
        sessions = sessions.filter { $0.key == "demo:demo" || now - $0.value.receivedAt < 5 }
        if sessions.count != oldCount {
            reconcileSource()
            refreshMedia()
            geometryChanged?()
        }
    }

    private func reconcileSource(incomingID: String? = nil, beganPlaying: Bool = false) {
        guard !demo else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let fresh = sessions.values.filter { $0.id != "demo:demo" && now - $0.receivedAt < 5 }
        var candidate: String?
        if automaticSource {
            if beganPlaying, let incomingID { candidate = incomingID }
            else if current == nil {
                candidate = fresh.sorted {
                    let firstPlaying = $0.snapshot.state == "playing" && !$0.snapshot.isAdvertisement
                    let secondPlaying = $1.snapshot.state == "playing" && !$1.snapshot.isAdvertisement
                    return firstPlaying == secondPlaying ? $0.receivedAt > $1.receivedAt : firstPlaying
                }.first?.id ?? ""
            }
        } else if current == nil, let preferredTab {
            candidate = fresh.filter { $0.snapshot.sourceId == preferredTab }.max { $0.receivedAt < $1.receivedAt }?.id
        }
        if let candidate, candidate != selectedSource { selectedSource = candidate }
    }

    func retryMedia() {
        if let key = trackKey { manualLyrics.remove(key) }
        lyricRequestID = nil
        artworkRequestID = nil
        refreshMedia(force: true)
    }

    func cancelLyricSearch() {
        searchTask?.cancel()
        searchToken = UUID()
        lyricCandidates = []
        lyricSearchBusy = false
        lyricSearchStatus = ""
        candidateTrackKey = nil
    }

    func searchLyrics(_ text: String) {
        cancelLyricSearch()
        guard lyricSource != "caption", let key = trackKey, let duration = current?.snapshot.duration,
              duration.isFinite, duration > 0 else {
            lyricSearchStatus = "Tunggu lagu aktif dan durasinya tersedia."
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 500 else {
            lyricSearchStatus = "Isi judul/artis, maksimal 500 karakter."
            return
        }
        let token = searchToken
        candidateTrackKey = key
        candidateDuration = duration
        lyricSearchBusy = true
        lyricSearchStatus = "Mencari kandidat…"
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let records = try await self.lyricsService.search(text, duration: duration)
                guard !Task.isCancelled, self.searchToken == token, self.trackKey == key else { return }
                self.candidateTrackKey = key
                self.candidateDuration = duration
                self.lyricCandidates = records
                self.lyricSearchStatus = records.isEmpty ? "Tidak ada hasil. Coba judul/alias lain." : "\(records.count) kandidat · urutan durasi terdekat, bukan jaminan versi cocok"
            } catch {
                guard !Task.isCancelled, self.searchToken == token, self.trackKey == key else { return }
                self.lyricSearchStatus = error.localizedDescription
            }
            self.lyricSearchBusy = false
        }
    }

    func selectLyrics(_ record: LyricsRecord) {
        guard let key = trackKey, candidateTrackKey == key, lyricSource != "caption",
              let duration = current?.snapshot.duration, let searchedDuration = candidateDuration,
              abs(duration - searchedDuration) <= 3 else {
            lyricSearchStatus = "Lagu/durasi berubah. Cari ulang sebelum memilih."
            return
        }
        lyricTask?.cancel()
        lyricRequestID = nil
        manualLyrics.insert(key)
        lyrics[key] = record.hasValidSyncedLyrics ? LRCParser.parse(record.syncedLyrics ?? "") : nil
        plainLyrics[key] = record.instrumental ? nil : record.plainLyrics
        lyricNames[key] = "LRCLIB #\(record.id) · \(record.artistName) — \(record.trackName)"
        lyricMessages[key] = record.instrumental ? "Instrumental" : record.hasValidSyncedLyrics ? "LRCLIB · bertimestamp · dipilih manual" : "LRCLIB · teks saja"
        lyricSearchStatus = "Dipilih #\(record.id). Cek timing; gunakan offset bila bergeser konstan."
    }

    private func refreshMedia(force: Bool = false) {
        if let candidateTrackKey, candidateTrackKey != trackKey { cancelLyricSearch() }
        guard let snapshot = current?.snapshot, let key = trackKey else {
            lyricTask?.cancel()
            artworkTask?.cancel()
            lyricRequestID = nil
            artworkRequestID = nil
            artwork = nil
            return
        }
        let videoIdentifier = snapshot.trackId.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil
        let fallbackArtwork = snapshot.sourceLabel.hasPrefix("YouTube") && videoIdentifier
            ? "https://i.ytimg.com/vi/\(snapshot.trackId)/hqdefault.jpg" : nil
        let imageAddress = snapshot.artworkURL ?? fallbackArtwork
        let imageID = key + ":" + (imageAddress ?? "")
        if artworkRequestID != imageID || Date() >= artworkRetryAfter {
            artworkTask?.cancel()
            artworkRequestID = imageID
            artworkRetryAfter = .distantFuture
            artwork = nil
            if let address = imageAddress {
                artworkTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        let image = try await self.artworkService.image(for: address)
                        guard !Task.isCancelled, self.artworkRequestID == imageID, self.trackKey == key else { return }
                        self.artwork = image
                        if image == nil { self.artworkRetryAfter = Date(timeIntervalSinceNow: 30) }
                    } catch {
                        guard !Task.isCancelled, self.artworkRequestID == imageID else { return }
                        self.artworkRetryAfter = Date(timeIntervalSinceNow: 30)
                    }
                }
            }
        }
        guard !demo, lyricSource != "caption", automaticLyrics, !manualLyrics.contains(key) else { return }
        let query = LyricsQuery(title: snapshot.title, artist: snapshot.artist, duration: snapshot.duration ?? 0)
        let signature = key + ":" + query.title + ":" + query.artist + ":" + String(query.duration)
        guard lyricRequestID != signature || Date() >= lyricRetryAfter else { return }
        lyricTask?.cancel()
        lyricRequestID = signature
        lyricRetryAfter = .distantFuture
        guard query.isSearchable else { lyricMessages[key] = "Menunggu metadata lagu yang lengkap"; return }
        if !force, resolvedQueries[key] == query, lyrics[key]?.isEmpty == false { return }
        lyrics[key] = nil
        plainLyrics[key] = nil
        lyricMessages[key] = "Mencari lirik otomatis…"
        lyricTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(650))
                let record = try await self.lyricsService.resolve(query, force: force)
                guard !Task.isCancelled, self.lyricRequestID == signature, self.trackKey == key else { return }
                self.resolvedQueries[key] = query
                self.lyrics[key] = nil
                self.plainLyrics[key] = nil
                guard let record else { self.lyricMessages[key] = "Lirik yang cocok belum ditemukan"; return }
                self.lyricNames[key] = "LRCLIB · \(record.artistName) — \(record.trackName)"
                if record.instrumental { self.lyricMessages[key] = "Instrumental · tidak ada lirik" }
                else if record.hasValidSyncedLyrics, let synced = record.syncedLyrics {
                    self.lyrics[key] = LRCParser.parse(synced)
                    self.lyricMessages[key] = "LRCLIB · bertimestamp (timing perlu dicek)"
                } else if let plain = record.plainLyrics, !plain.isEmpty {
                    self.plainLyrics[key] = plain
                    self.lyricMessages[key] = "Lirik teks · belum tersinkron"
                } else { self.lyricMessages[key] = "Lirik belum tersedia" }
            } catch {
                guard !Task.isCancelled, self.lyricRequestID == signature, self.trackKey == key else { return }
                self.lyricMessages[key] = "Lirik belum terhubung · mencoba lagi otomatis"
                self.lyricNames[key] = error.localizedDescription
                self.lyricRetryAfter = Date(timeIntervalSinceNow: 30)
            }
        }
    }

    func command(_ action: String, position: Double? = nil) {
        guard let current, canControl else { return }
        if demo {
            var snapshot = current.snapshot
            snapshot.position = self.position()
            if action == "toggle" { snapshot.state = snapshot.state == "playing" ? "paused" : "playing" }
            else if action == "seek", let position { snapshot.position = min(204, max(0, position)) }
            else { snapshot.position = 0 }
            sessions[current.id] = PlaybackSession(snapshot: snapshot, receivedAt: ProcessInfo.processInfo.systemUptime)
            return
        }
        let identifier = UUID().uuidString
        var packet: [String: Any] = [
            "protocolVersion": 1, "kind": "command", "commandId": identifier,
            "sourceId": current.snapshot.sourceId, "sessionId": current.snapshot.sessionId,
            "trackId": current.snapshot.trackId, "action": action
        ]
        if let position, position.isFinite { packet["position"] = position }
        guard let encoded = try? JSONSerialization.data(withJSONObject: packet) else { return }
        commandError = nil
        pendingCommand = identifier
        sendPacket?(encoded)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.pendingCommand == identifier else { return }
            self.pendingCommand = nil
            self.commandError = "Pemutar tidak merespons. Periksa koneksi Chrome."
        }
    }

    func importLyrics() {
        guard let key = trackKey else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Pilih LRC untuk lagu aktif. Pastikan versi rekamannya cocok."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard key == trackKey else { commandError = "Lagu berubah saat memilih lirik. Silakan ulangi."; return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_000_000 else { throw BridgeError.system("Berkas lirik maksimal 1 MB.") }
            let parsed = LRCParser.parse(try String(contentsOf: url, encoding: .utf8))
            guard !parsed.isEmpty else { throw BridgeError.system("Tidak ada timestamp LRC yang valid.") }
            lyricTask?.cancel()
            manualLyrics.insert(key)
            lyrics[key] = parsed
            plainLyrics[key] = nil
            lyricMessages[key] = "LRC manual"
            lyricNames[key] = url.lastPathComponent
            commandError = nil
        } catch { commandError = error.localizedDescription }
    }

    private func save() {
        defaults.set(panelWidth, forKey: "panelWidth")
        defaults.set(accentName, forKey: "accentName")
        defaults.set(animations, forKey: "animations")
        defaults.set(showLyrics, forKey: "showLyrics")
        defaults.set(lyricSource, forKey: "lyricSource")
        defaults.set(automaticSource, forKey: "automaticSource")
        defaults.set(automaticLyrics, forKey: "automaticLyrics")
    }

    private func configureDemo() {
        if demo {
            let packet: [String: Any] = [
                "protocolVersion": 1, "kind": "snapshot", "sessionId": "demo", "sourceId": "demo",
                "sourceLabel": "Demo lokal", "sequence": 0, "trackId": "senja", "title": "Senja di Jendela",
                "artist": "Ruang Sore · demo original", "position": 12, "duration": 204,
                "playbackRate": 1, "state": "playing", "isAdvertisement": false,
                "capabilities": ["playPause": true, "previous": true, "next": true, "seek": true]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: packet),
               let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data) {
                sessions["demo:demo"] = PlaybackSession(snapshot: snapshot, receivedAt: ProcessInfo.processInfo.systemUptime)
            }
            lyrics["Demo lokal:senja"] = LRCParser.parse("[00:00]Langit menyimpan warna kita\n[00:10]Pelan, kota mulai bercahaya\n[00:20]Dan waktu singgah sebentar saja\n[00:30]Kita pulang bersama senja\n[00:45]\n")
        } else { sessions.removeValue(forKey: "demo:demo") }
        pendingCommand = nil
        reconcileSource()
        refreshMedia()
        geometryChanged?()
    }
}
