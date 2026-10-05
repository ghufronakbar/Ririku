import AppKit
import Combine
import RirikuCore

struct PlaybackSession {
    var snapshot: PlaybackSnapshot
    var receivedAt: TimeInterval
    var id: String { snapshot.sessionId + ":" + snapshot.sourceId }
}

/// Music in the notch: player sessions from the browser extension and the desktop players, source selection,
/// playback commands, artwork, lyrics, and the browser connection steps in Setup.
/// Lyrics display, layout, and search are in `MusicModel+Lyrics.swift`.
@MainActor
final class MusicModel: ObservableObject {
    @Published var sessions: [String: PlaybackSession] = [:]
    @Published var selectedSource = "" {
        didSet {
            commandError = nil
            pendingCommand = nil
            if !automaticSource { preferredTab = sessions[selectedSource]?.snapshot.sourceId ?? preferredTab }
            refreshMedia()
            layoutChanged?()
        }
    }
    @Published var automaticSource: Bool {
        didSet {
            preferredTab = current?.snapshot.sourceId
            defaults.set(automaticSource, forKey: "automaticSource")
            reconcileSource()
        }
    }
    @Published var automaticLyrics: Bool {
        didSet {
            defaults.set(automaticLyrics, forKey: "automaticLyrics")
            lyricTask?.cancel()
            lyricRequestID = nil
            if !automaticLyrics, let key = trackKey, currentLines.isEmpty { lyricMessages[key] = UIText("Automatic lyrics off") }
            refreshMedia()
        }
    }
    /// Follows the interface language, which `AppModel` owns.
    @Published var localizer: Localizer
    @Published var lyricLineCount: Int { didSet { defaults.set(lyricLineCount, forKey: "lyricLineCount"); layoutChanged?() } }
    @Published var preferJapaneseLyrics: Bool {
        didSet { displayLineCache.removeAll(); defaults.set(preferJapaneseLyrics, forKey: "preferJapaneseLyrics") }
    }
    @Published var showLyrics: Bool { didSet { defaults.set(showLyrics, forKey: "showLyrics"); layoutChanged?() } }
    @Published var lyricSource: String {
        didSet {
            defaults.set(lyricSource, forKey: "lyricSource")
            lyricNoticeTask?.cancel()
            lyricNoticeText = nil
            lyricTask?.cancel()
            lyricRequestID = nil
            if lyricSource == "caption" { cancelLyricSearch() }
            refreshMedia()
        }
    }
    @Published var lyricOffsets: [String: Double]
    @Published var lyricCandidates: [LyricsRecord] = []
    @Published var lyricSearchStatus: UIText?
    @Published var lyricSearchBusy = false
    @Published var lyricNoticeText: UIText?
    @Published var demo = false { didSet { configureDemo() } }
    @Published var lyrics: [String: [LyricLine]] = [:] { didSet { displayLineCache.removeAll(); twoRowCache.removeAll(); layoutChanged?() } }
    @Published var lyricNames: [String: UIText] = [:]
    @Published var lyricMessages: [String: UIText] = [:]
    @Published var plainLyrics: [String: String] = [:] { didSet { layoutChanged?() } }
    @Published var artwork: NSImage? { didSet { artworkChanged?(artwork) } }
    @Published var commandError: UIText? { didSet { layoutChanged?() } }
    @Published var bridgeError: UIText?
    @Published var connectedExtensionVersion: String?
    /// The browser whose native host is connected, reported by `RirikuHost` from its parent process.
    @Published var connectedBrowser: String?
    @Published var browserSetupMessage: UIText?
    /// Incremented after a browser setup action so the file-based status is read again on the next render.
    @Published private(set) var browserSetupRevision = 0
    @Published var pendingCommand: String?

    /// Called whenever something that sets the panel's size changes.
    var layoutChanged: (() -> Void)?
    var openSetup: (() -> Void)?
    var artworkChanged: ((NSImage?) -> Void)?
    var sendPacket: ((Data) -> Void)?

    // Lyrics state used by `MusicModel+Lyrics.swift`.
    var displayLineCache: [String: [LyricLine]] = [:]
    /// Measured once per song and island width, because measuring every line on each render is wasteful.
    var twoRowCache: [String: Bool] = [:]
    var lyricNoticeKey: String?
    var lyricNoticeTask: Task<Void, Never>?
    var notifiedMissingTracks = Set<String>()
    var searchTask: Task<Void, Never>?
    var searchToken = UUID()
    var candidateTrackKey: String?
    var candidateSearchIdentity: String?
    var candidateDuration: Double?
    let lyricsService: LyricsService
    /// Display-only translation of the current song's lyrics (D-027).
    let lyricTranslator: LyricTranslator
    var lyricTask: Task<Void, Never>?
    var lyricRequestID: String?
    var manualLyrics = Set<String>()
    var resolvedQueries: [String: LyricsQuery] = [:]
    var lyricRetryAfter = Date.distantFuture
    let defaults: UserDefaults

    private var timer: Timer?
    private var lastTrackKey: String?
    private var preferredTab: String?
    private let artworkService = ArtworkService()
    private var artworkTask: Task<Void, Never>?
    private var artworkRequestID: String?
    private var artworkRetryAfter = Date.distantFuture

    init(lyricsService: LyricsService = LyricsService(), defaults: UserDefaults = .standard, localizer: Localizer = Localizer(code: "en")) {
        self.lyricsService = lyricsService
        self.defaults = defaults
        self.localizer = localizer
        lyricTranslator = LyricTranslator(defaults: defaults, defaultTarget: localizer.code)
        automaticSource = defaults.object(forKey: "automaticSource") as? Bool ?? true
        automaticLyrics = defaults.object(forKey: "automaticLyrics") as? Bool ?? true
        let storedLineCount = defaults.integer(forKey: "lyricLineCount")
        lyricLineCount = (1...3).contains(storedLineCount) ? storedLineCount : 3
        preferJapaneseLyrics = defaults.object(forKey: "preferJapaneseLyrics") as? Bool ?? true
        showLyrics = defaults.object(forKey: "showLyrics") as? Bool ?? true
        let storedSource = defaults.string(forKey: "lyricSource") ?? "auto"
        lyricSource = ["auto", "lrclib", "caption"].contains(storedSource) ? storedSource : "auto"
        lyricOffsets = (defaults.dictionary(forKey: "lyricOffsetsByTrack") as? [String: Double] ?? [:]).filter { $0.value.isFinite && abs($0.value) <= 60 }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.expireSessions() }
        }
        lyricTranslator.changed = { [weak self] in
            self?.objectWillChange.send()
            self?.layoutChanged?()
        }
    }

    func t(_ key: String, _ arguments: String...) -> String { localizer.string(key, arguments) }
    func t(_ text: UIText) -> String { localizer.string(text.key, text.arguments) }

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

    /// The demo label is translated; labels from the extension are service names and stay as they are.
    func sourceLabel(for snapshot: PlaybackSnapshot) -> String {
        if snapshot.sourceId == "desktop", let adapter = desktopAdapters[snapshot.sessionId + ":desktop"] { return adapter.player.label }
        if snapshot.sessionId == "demo" && snapshot.sourceId == "demo" { return t("Local demo") }
        guard let browser = connectedBrowser else { return snapshot.sourceLabel }
        // The extension labels the website; the browser part is replaced with the one that connected.
        let service = snapshot.sourceLabel.components(separatedBy: " · ").first ?? snapshot.sourceLabel
        return service + " · " + browser
    }

    var isPlayingNow: Bool { current?.snapshot.state == "playing" && current?.snapshot.isAdvertisement == false }
    var canControl: Bool { current != nil && current?.snapshot.isAdvertisement == false && pendingCommand == nil }

    func position() -> Double {
        guard let current else { return 0 }
        return current.snapshot.position(at: ProcessInfo.processInfo.systemUptime, receivedAt: current.receivedAt, staleAfter: demo ? .greatestFiniteMagnitude : 5)
    }

    // MARK: Desktop players

    @Published var spotifyEnabled = false {
        didSet { defaults.set(spotifyEnabled, forKey: "spotifyEnabled"); spotify.setEnabled(spotifyEnabled) }
    }
    @Published var spotifyStatus = DesktopPlayer.spotify.idleStatus
    @Published var appleMusicEnabled = false {
        didSet { defaults.set(appleMusicEnabled, forKey: "appleMusicEnabled"); appleMusic.setEnabled(appleMusicEnabled) }
    }
    @Published var appleMusicStatus = DesktopPlayer.appleMusic.idleStatus
    private lazy var spotify = makeDesktopAdapter(.spotify) { [weak self] in self?.spotifyStatus = $0 }
    private lazy var appleMusic = makeDesktopAdapter(.appleMusic) { [weak self] in self?.appleMusicStatus = $0 }
    var desktopAdapters: [String: DesktopPlayerAdapter] { [spotify.player.id: spotify, appleMusic.player.id: appleMusic] }

    private func makeDesktopAdapter(_ player: DesktopPlayer, status: @escaping (UIText) -> Void) -> DesktopPlayerAdapter {
        let adapter = DesktopPlayerAdapter(player: player)
        adapter.onPacket = { [weak self] data in self?.receive(data) }
        adapter.onStatus = status
        return adapter
    }

    func startDesktopPlayers() {
        spotifyEnabled = defaults.bool(forKey: "spotifyEnabled")
        appleMusicEnabled = defaults.bool(forKey: "appleMusicEnabled")
    }
    func reconnectSpotify() { spotify.setEnabled(spotifyEnabled) }
    func reconnectAppleMusic() { appleMusic.setEnabled(appleMusicEnabled) }

    // MARK: Sessions and source selection

    func receive(_ data: Data) {
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["protocolVersion"] as? Int == 1 else { return }
        if envelope["kind"] as? String == "openSetup" { openSetup?(); return }
        if envelope["kind"] as? String == "host" {
            // Only the names Ririku knows are accepted, so the label can never come from page data.
            connectedBrowser = (envelope["browser"] as? String).flatMap { Browser.named($0)?.name }
            return
        }
        if envelope["kind"] as? String == "extension" {
            if let version = envelope["version"] as? String, version.range(of: #"^[0-9]+(\.[0-9]+){0,3}$"#, options: .regularExpression) != nil {
                connectedExtensionVersion = version
            }
            return
        }
        if envelope["kind"] as? String == "ack" {
            guard let commandId = envelope["commandId"] as? String, commandId == pendingCommand else { return }
            pendingCommand = nil
            if envelope["ok"] as? Bool != true { commandError = UIText("Control failed. Try again from the player tab.") }
            return
        }
        if envelope["kind"] as? String == "remove", let source = envelope["sourceId"] as? String,
           let session = envelope["sessionId"] as? String {
            sessions.removeValue(forKey: session + ":" + source)
            reconcileSource()
            refreshMedia()
            layoutChanged?()
            return
        }
        guard let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data), snapshot.isValid else { return }
        let entry = PlaybackSession(snapshot: snapshot, receivedAt: ProcessInfo.processInfo.systemUptime)
        if let previous = sessions[entry.id], snapshot.sequence <= previous.snapshot.sequence { return }
        let beganPlaying = snapshot.state == "playing" && !snapshot.isAdvertisement
            && (sessions[entry.id]?.snapshot.state != "playing" || sessions[entry.id]?.snapshot.isAdvertisement == true
                || sessions[entry.id]?.snapshot.trackId != snapshot.trackId)
        sessions[entry.id] = entry
        reconcileSource(incomingID: entry.id, beganPlaying: beganPlaying)
        refreshMedia()
        if !demo && current?.id == entry.id {
            let key = snapshot.isAdvertisement ? nil : trackKey
            if lastTrackKey != key {
                lastTrackKey = key
                commandError = nil
                pendingCommand = nil
            }
        }
        layoutChanged?()
    }

    func disconnect() {
        connectedExtensionVersion = nil
        connectedBrowser = nil
        sessions = sessions.filter { $0.key == "demo:demo" || desktopAdapters[$0.key] != nil }
        pendingCommand = nil
        refreshMedia()
        layoutChanged?()
    }

    private func expireSessions() {
        let now = ProcessInfo.processInfo.systemUptime
        let oldCount = sessions.count
        sessions = sessions.filter { $0.key == "demo:demo" || now - $0.value.receivedAt < 5 }
        if sessions.count != oldCount {
            reconcileSource()
            refreshMedia()
            layoutChanged?()
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

    // MARK: Commands

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
        if let adapter = desktopAdapters[current.id] { adapter.send(encoded) }
        else { sendPacket?(encoded) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.pendingCommand == identifier else { return }
            self.pendingCommand = nil
            self.commandError = UIText("Player not responding. Check the browser connection.")
        }
    }

    // MARK: Artwork and lyrics refresh

    func retryMedia() {
        if let key = trackKey { manualLyrics.remove(key) }
        lyricRequestID = nil
        artworkRequestID = nil
        refreshMedia(force: true)
    }

    func refreshMedia(force: Bool = false) {
        if lyricNoticeKey != trackKey {
            lyricNoticeTask?.cancel()
            lyricNoticeText = nil
            lyricNoticeKey = nil
        }
        if let candidateTrackKey, candidateTrackKey != trackKey || candidateSearchIdentity != lyricSearchIdentity { cancelLyricSearch() }
        guard let snapshot = current?.snapshot, let key = trackKey else {
            lyricTask?.cancel()
            artworkTask?.cancel()
            lyricRequestID = nil
            artworkRequestID = nil
            artwork = nil
            return
        }
        refreshArtwork(snapshot: snapshot, key: key)
        refreshLyrics(snapshot: snapshot, key: key, force: force)
    }

    private func refreshArtwork(snapshot: PlaybackSnapshot, key: String) {
        let videoIdentifier = snapshot.trackId.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil
        let fallbackArtwork = snapshot.sourceLabel.hasPrefix("YouTube") && videoIdentifier
            ? "https://i.ytimg.com/vi/\(snapshot.trackId)/hqdefault.jpg" : nil
        let imageAddress = snapshot.artworkURL ?? fallbackArtwork
        let imageID = key + ":" + (imageAddress ?? "")
        guard artworkRequestID != imageID || Date() >= artworkRetryAfter else { return }
        artworkTask?.cancel()
        artworkRequestID = imageID
        artworkRetryAfter = .distantFuture
        artwork = nil
        let desktop = imageAddress == nil ? desktopAdapters[current?.id ?? ""] : nil
        guard imageAddress != nil || desktop != nil else { return }
        artworkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = if let address = imageAddress { try await self.artworkService.image(for: address) }
                    else { await desktop?.artwork(for: snapshot.trackId) }
                guard !Task.isCancelled, self.artworkRequestID == imageID, self.trackKey == key else { return }
                self.artwork = image
                if image == nil { self.artworkRetryAfter = Date(timeIntervalSinceNow: 30) }
            } catch {
                guard !Task.isCancelled, self.artworkRequestID == imageID else { return }
                self.artworkRetryAfter = Date(timeIntervalSinceNow: 30)
            }
        }
    }

    // MARK: Browser connection

    func connectBrowsers() {
        do {
            let browsers = try BrowserSetup.registerHosts()
            browserSetupMessage = UIText("Connection registered for %@. Load the extension, then refresh an open YouTube tab.",
                                         browsers.map(\.name).joined(separator: ", "))
        } catch { browserSetupMessage = UIText(error: error) }
        browserSetupRevision += 1
    }

    func showExtensionFolder() {
        do {
            let folder = try BrowserSetup.installExtension()
            NSWorkspace.shared.activateFileViewerSelecting([folder])
            browserSetupMessage = nil
        } catch { browserSetupMessage = UIText(error: error) }
        browserSetupRevision += 1
    }

    func copyExtensionsPage(for browser: Browser) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(browser.extensionsPage, forType: .string)
        browserSetupMessage = UIText("Copied %@. Paste it into the address bar of %@.", browser.extensionsPage, browser.name)
    }

    // MARK: Local demo

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
        layoutChanged?()
    }
}
