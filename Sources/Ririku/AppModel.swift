import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RirikuCore

/// Row sizes of the expanded panel. `PlayerView` lays out with the same values, so the window is
/// exactly as tall as the rows it draws instead of a guessed constant.
enum ExpandedLayout {
    static let spacing: Double = 12
    static let topPadding: Double = 12
    static let bottomPadding: Double = 14
    static let horizontalPadding: Double = 22
    static let artworkSize: Double = 48
    static let seekBarHeight: Double = 20
    static let seekLabelSpacing: Double = 2
    static let timeRowHeight: Double = 13
    static let transportHeight: Double = 32
    static let transportSpacing: Double = 24
    /// Two lines of `caption2`, the limit on the command error.
    static let errorHeight: Double = 26
}

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
            if !automaticLyrics, let key = trackKey, currentLines.isEmpty { lyricMessages[key] = UIText("Automatic lyrics off") }
            refreshMedia()
        }
    }
    @Published var interfaceLanguage: InterfaceLanguage {
        didSet {
            localizer = Localizer(code: interfaceLanguage.resolvedCode)
            save()
            languageChanged?()
        }
    }
    private(set) var localizer: Localizer
    @Published var expanded = false { didSet { geometryChanged?() } }
    @Published var panelWidth: Double { didSet { save(); geometryChanged?() } }
    /// Compact island size is stored as the amount added to the physical notch, so 0 fits the notch on any Mac.
    @Published var compactExtraWidth: Double { didSet { save(); geometryChanged?() } }
    @Published var compactExtraHeight: Double { didSet { save(); geometryChanged?() } }
    @Published var lyricLineCount: Int { didSet { save(); geometryChanged?() } }
    @Published var accentName: String { didSet { save() } }
    @Published var animations: Bool { didSet { save(); geometryChanged?() } }
    @Published var preferJapaneseLyrics: Bool { didSet { displayLineCache.removeAll(); save() } }
    private var displayLineCache: [String: [LyricLine]] = [:]
    @Published private var lyricNoticeText: UIText?
    private var lyricNoticeKey: String?
    private var lyricNoticeTask: Task<Void, Never>?
    private var notifiedMissingTracks = Set<String>()
    @Published var showLyrics: Bool { didSet { save(); geometryChanged?() } }
    @Published var lyricSource: String {
        didSet {
            save()
            lyricNoticeTask?.cancel()
            lyricNoticeText = nil
            lyricTask?.cancel()
            lyricRequestID = nil
            if lyricSource == "caption" { cancelLyricSearch() }
            refreshMedia()
        }
    }
    @Published private var lyricOffsets: [String: Double]
    @Published var lyricCandidates: [LyricsRecord] = []
    @Published var lyricSearchStatus: UIText?
    @Published var lyricSearchBusy = false
    private var searchTask: Task<Void, Never>?
    private var searchToken = UUID()
    private var candidateTrackKey: String?
    private var candidateSearchIdentity: String?
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
    @Published var lyrics: [String: [LyricLine]] = [:] { didSet { displayLineCache.removeAll(); geometryChanged?() } }
    @Published var lyricNames: [String: UIText] = [:]
    @Published var lyricMessages: [String: UIText] = [:]
    @Published var plainLyrics: [String: String] = [:] { didSet { geometryChanged?() } }
    @Published var artwork: NSImage?
    @Published var commandError: UIText? { didSet { geometryChanged?() } }
    @Published var bridgeError: UIText?
    @Published var connectedExtensionVersion: String?
    /// The browser whose native host is connected, reported by `RirikuHost` from its parent process.
    @Published var connectedBrowser: String?
    @Published var browserSetupMessage: UIText?
    /// Incremented after a browser setup action so the file-based status is read again on the next render.
    @Published private(set) var browserSetupRevision = 0
    @Published var loginItemMessage: UIText?
    /// Incremented after a launch-at-login change or a Setup visit, because macOS owns that state.
    @Published private(set) var loginItemRevision = 0
    @Published var pendingCommand: String?
    @Published var notchWidth: CGFloat = 180
    @Published var topHeight: CGFloat = 34
    var geometryChanged: (() -> Void)?
    var openSetup: (() -> Void)?
    var languageChanged: (() -> Void)?
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
        let storedLanguage = InterfaceLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .system
        interfaceLanguage = storedLanguage
        localizer = Localizer(code: storedLanguage.resolvedCode)
        automaticSource = defaults.object(forKey: "automaticSource") as? Bool ?? true
        automaticLyrics = defaults.object(forKey: "automaticLyrics") as? Bool ?? true
        let storedWidth = defaults.double(forKey: "panelWidth")
        panelWidth = storedWidth.isFinite && (360...720).contains(storedWidth) ? storedWidth : 442
        let storedExtraWidth = defaults.double(forKey: "compactExtraWidth")
        compactExtraWidth = storedExtraWidth.isFinite && (0...Self.compactWidthRange).contains(storedExtraWidth) ? storedExtraWidth : 0
        let storedExtraHeight = defaults.double(forKey: "compactExtraHeight")
        compactExtraHeight = storedExtraHeight.isFinite && (0...Self.compactHeightRange).contains(storedExtraHeight) ? storedExtraHeight : 0
        // The old absolute width was always wider than the notch, which is what this replaces.
        defaults.removeObject(forKey: "compactWidth")
        let storedLineCount = defaults.integer(forKey: "lyricLineCount")
        lyricLineCount = (1...3).contains(storedLineCount) ? storedLineCount : 3
        accentName = defaults.string(forKey: "accentName") ?? "Peach"
        animations = defaults.object(forKey: "animations") as? Bool ?? true
        preferJapaneseLyrics = defaults.object(forKey: "preferJapaneseLyrics") as? Bool ?? true
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

    var lyricSearchIdentity: String? {
        guard let key = trackKey, let snapshot = current?.snapshot else { return nil }
        return [key, snapshot.title, snapshot.artist].joined(separator: "\u{1F}")
    }

    var suggestedLyricSearch: String {
        guard let snapshot = current?.snapshot else { return "" }
        let query = LyricsQuery(title: snapshot.title, artist: snapshot.artist, duration: snapshot.duration ?? 0)
        return [query.title, query.artist].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var locale: Locale { localizer.locale }
    func t(_ key: String, _ arguments: String...) -> String { localizer.string(key, arguments) }
    func t(_ text: UIText) -> String { localizer.string(text.key, text.arguments) }

    /// The demo label is translated; labels from the extension are service names and stay as they are.
    func sourceLabel(for snapshot: PlaybackSnapshot) -> String {
        if snapshot.sessionId == "demo" && snapshot.sourceId == "demo" { return t("Local demo") }
        guard let browser = connectedBrowser else { return snapshot.sourceLabel }
        // The extension labels the website; the browser part is replaced with the one that connected.
        let service = snapshot.sourceLabel.components(separatedBy: " · ").first ?? snapshot.sourceLabel
        return service + " · " + browser
    }

    var accent: Color {
        switch accentName {
        case "Lavender": return Color(red: 0.78, green: 0.75, blue: 1)
        case "Netral": return .white
        default: return Color(red: 0.96, green: 0.78, blue: 0.7)
        }
    }

    var canAnimate: Bool { animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// How far the compact island may grow past the notch, on each axis.
    static let compactWidthRange: Double = 440
    static let compactHeightRange: Double = 40

    /// Total compact size, which the sliders in Setup show and set.
    var compactWidth: Double { notchWidth + compactExtraWidth }
    var islandHeight: Double { topHeight + (current == nil ? 0 : compactExtraHeight) }
    /// Artwork and spectrum shrink with a short island so they never spill out of it.
    var compactIconSize: Double { max(14, min(24, islandHeight - 8)) }
    func resetIslandSize() {
        compactExtraWidth = 0
        compactExtraHeight = 0
        panelWidth = 442
    }
    var isPlayingNow: Bool { current?.snapshot.state == "playing" && current?.snapshot.isAdvertisement == false }
    var popupDuration: Double { 0.32 }
    var lyricBlockHeight: Double { Double(min(3, max(1, lyricLineCount)) * 20 + 14) }
    var hasIslandLyrics: Bool {
        showLyrics && (usesVideoCaption || !currentLines.isEmpty || !(currentPlainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
    }
    var lyricNotice: String? {
        guard showLyrics, !hasIslandLyrics, lyricNoticeKey == trackKey, let lyricNoticeText else { return nil }
        return t(lyricNoticeText)
    }
    var islandLyricHeight: Double {
        guard expanded || isPlayingNow else { return 0 }
        return hasIslandLyrics ? lyricBlockHeight : lyricNotice != nil ? 34 : 0
    }

    var expandedContentHeight: Double {
        var height = ExpandedLayout.topPadding + ExpandedLayout.artworkSize
            + ExpandedLayout.spacing + ExpandedLayout.seekBarHeight + ExpandedLayout.seekLabelSpacing + ExpandedLayout.timeRowHeight
            + ExpandedLayout.spacing + ExpandedLayout.transportHeight
            + ExpandedLayout.bottomPadding
        if islandLyricHeight > 0 { height += islandLyricHeight + ExpandedLayout.spacing }
        if commandError != nil { height += ExpandedLayout.errorHeight + ExpandedLayout.spacing }
        return height
    }

    func panelSize(screenWidth: Double) -> CGSize {
        let active = current != nil
        let width = expanded ? max(panelWidth, notchWidth + 120) : active ? compactWidth : notchWidth
        let extraHeight = expanded ? expandedContentHeight : active ? islandLyricHeight : 0
        return CGSize(width: min(max(0, screenWidth - 24), width), height: islandHeight + extraHeight)
    }

    func displayedLyricRows() -> [(text: String, active: Bool)] {
        guard let index = lyricIndex(), !currentLines.isEmpty else { return [(lyricStatus, true)] }
        let offsets = lyricLineCount == 1 ? [0] : lyricLineCount == 2 ? [0, 1] : [-1, 0, 1]
        return offsets.map { offset in
            let target = index + offset
            let text = currentLines.indices.contains(target) ? currentLines[target].text : ""
            return (text.isEmpty ? (offset == 0 ? "♪" : " ") : text, offset == 0)
        }
    }
    var usesVideoCaption: Bool {
        lyricSource != "lrclib" && (lyricSource == "caption" || currentLines.isEmpty)
            && current?.snapshot.captionEnabled == true && current?.snapshot.isAdvertisement == false
    }
    var currentLines: [LyricLine] {
        guard lyricSource != "caption", let key = trackKey else { return [] }
        if let cached = displayLineCache[key] { return cached }
        let prepared = LRCParser.displayLines(lyrics[key] ?? [], preferJapanese: preferJapaneseLyrics)
        displayLineCache[key] = prepared
        return prepared
    }
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
        guard let current else { return t("Waiting for music in your browser") }
        if current.snapshot.isAdvertisement { return t("Ad · lyrics paused") }
        if usesVideoCaption {
            let caption = current.snapshot.captionText ?? ""
            return caption.isEmpty ? "♪" : caption
        }
        if lyricSource == "caption" { return t("Captions unavailable · turn on CC or choose LRCLIB") }
        if currentLines.isEmpty {
            if let key = trackKey {
                if let message = lyricMessages[key] { return t(message) }
                return automaticLyrics ? t("Searching lyrics…") : t("Automatic lyrics off")
            }
            return t("Lyrics not available yet")
        }
        guard let index = lyricIndex() else { return "♪" }
        return currentLines[index].text.isEmpty ? "♪" : currentLines[index].text
    }

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
            geometryChanged?()
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
        geometryChanged?()
    }

    func disconnect() {
        connectedExtensionVersion = nil
        connectedBrowser = nil
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
        lyricSearchStatus = nil
        candidateTrackKey = nil
        candidateSearchIdentity = nil
    }

    func searchLyrics(_ text: String) {
        cancelLyricSearch()
        guard lyricSource != "caption", let key = trackKey, let duration = current?.snapshot.duration,
              duration.isFinite, duration > 0 else {
            lyricSearchStatus = UIText("Wait for an active song with a known duration.")
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 500 else {
            lyricSearchStatus = UIText("Enter a title or artist, up to 500 characters.")
            return
        }
        let token = searchToken
        candidateTrackKey = key
        candidateSearchIdentity = lyricSearchIdentity
        candidateDuration = duration
        lyricSearchBusy = true
        lyricSearchStatus = UIText("Searching candidates…")
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let records = try await self.lyricsService.search(text, duration: duration)
                guard !Task.isCancelled, self.searchToken == token, self.trackKey == key else { return }
                self.candidateTrackKey = key
                self.candidateDuration = duration
                self.lyricCandidates = records
                self.lyricSearchStatus = records.isEmpty ? UIText("No results. Try another title or alias.")
                    : UIText("Candidates: %@ · sorted by closest duration, not a version guarantee", String(records.count))
            } catch {
                guard !Task.isCancelled, self.searchToken == token, self.trackKey == key else { return }
                self.lyricSearchStatus = UIText(error: error)
            }
            self.lyricSearchBusy = false
        }
    }

    func selectLyrics(_ record: LyricsRecord) {
        guard let key = trackKey, candidateTrackKey == key, candidateSearchIdentity == lyricSearchIdentity, lyricSource != "caption",
              let duration = current?.snapshot.duration, let searchedDuration = candidateDuration,
              abs(duration - searchedDuration) <= 3 else {
            lyricSearchStatus = UIText("Song or duration changed. Search again before choosing.")
            return
        }
        lyricTask?.cancel()
        lyricRequestID = nil
        manualLyrics.insert(key)
        lyrics[key] = record.hasValidSyncedLyrics ? LRCParser.parse(record.syncedLyrics ?? "") : nil
        plainLyrics[key] = record.instrumental ? nil : record.plainLyrics
        lyricNames[key] = UIText("LRCLIB #%@ · %@ — %@", String(record.id), record.artistName, record.trackName)
        lyricMessages[key] = record.instrumental ? UIText("Instrumental")
            : record.hasValidSyncedLyrics ? UIText("LRCLIB · timestamped · chosen manually") : UIText("LRCLIB · text only")
        lyricSearchStatus = UIText("Selected #%@. Check timing; use offset for a constant shift.", String(record.id))
    }

    private func refreshMedia(force: Bool = false) {
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
        guard query.isSearchable else { lyricMessages[key] = UIText("Waiting for complete song metadata"); return }
        if !force, resolvedQueries[key] == query, lyrics[key]?.isEmpty == false { return }
        lyrics[key] = nil
        plainLyrics[key] = nil
        lyricMessages[key] = UIText("Searching lyrics automatically…")
        lyricTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(650))
                let record = try await self.lyricsService.resolve(query, force: force)
                guard !Task.isCancelled, self.lyricRequestID == signature, self.trackKey == key else { return }
                self.resolvedQueries[key] = query
                self.lyrics[key] = nil
                self.plainLyrics[key] = nil
                guard let record else {
                    self.lyricMessages[key] = UIText("No matching lyrics found yet")
                    self.showMissingLyricsNotice(for: key)
                    return
                }
                self.lyricNames[key] = UIText("LRCLIB · %@ — %@", record.artistName, record.trackName)
                if record.instrumental { self.lyricMessages[key] = UIText("Instrumental · no lyrics") }
                else if record.hasValidSyncedLyrics, let synced = record.syncedLyrics {
                    self.lyrics[key] = LRCParser.parse(synced)
                    self.lyricMessages[key] = UIText("LRCLIB · timestamped (check timing)")
                } else if let plain = record.plainLyrics, !plain.isEmpty {
                    self.plainLyrics[key] = plain
                    self.lyricMessages[key] = UIText("Text lyrics · not synced")
                } else {
                    self.lyricMessages[key] = UIText("Lyrics not available yet")
                    self.showMissingLyricsNotice(for: key)
                }
            } catch {
                guard !Task.isCancelled, self.lyricRequestID == signature, self.trackKey == key else { return }
                self.lyricMessages[key] = UIText("Lyrics service unreachable · retrying automatically")
                self.lyricNames[key] = UIText(error: error)
                self.lyricRetryAfter = Date(timeIntervalSinceNow: 30)
            }
        }
    }

    private func showMissingLyricsNotice(for key: String) {
        guard trackKey == key, showLyrics, !hasIslandLyrics, !notifiedMissingTracks.contains(key) else { return }
        notifiedMissingTracks.insert(key)
        lyricNoticeTask?.cancel()
        lyricNoticeKey = key
        lyricNoticeText = UIText("Lyrics not found")
        geometryChanged?()
        lyricNoticeTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, self.lyricNoticeKey == key else { return }
            self.lyricNoticeText = nil
            self.geometryChanged?()
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
            self.commandError = UIText("Player not responding. Check the browser connection.")
        }
    }

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

    var launchAtLogin: Bool { LoginItem.state() == .on }

    /// The toggle writes straight to macOS; the interface follows the state it reports back.
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginItemMessage = nil
        } catch { loginItemMessage = UIText(error: error) }
        loginItemRevision += 1
    }

    /// Login items can also be changed in System Settings, so the state is read again when Setup opens.
    func refreshLoginItem() { loginItemRevision += 1 }

    func openLoginItemsSettings() { NSWorkspace.shared.open(LoginItem.settingsURL) }

    func copyExtensionsPage(for browser: Browser) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(browser.extensionsPage, forType: .string)
        browserSetupMessage = UIText("Copied %@. Paste it into the address bar of %@.", browser.extensionsPage, browser.name)
    }

    func importLyrics() {
        guard let key = trackKey else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = t("Choose an LRC for the current song. Make sure the recording version matches.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard key == trackKey else { commandError = UIText("The song changed while choosing lyrics. Please try again."); return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_000_000 else { throw BridgeError.system("Lyrics file must be 1 MB or smaller.") }
            let parsed = LRCParser.parse(try String(contentsOf: url, encoding: .utf8))
            guard !parsed.isEmpty else { throw BridgeError.system("No valid LRC timestamps found.") }
            lyricTask?.cancel()
            manualLyrics.insert(key)
            lyrics[key] = parsed
            plainLyrics[key] = nil
            lyricMessages[key] = UIText("Manual LRC")
            lyricNames[key] = UIText("%@", url.lastPathComponent)
            commandError = nil
        } catch { commandError = UIText(error: error) }
    }

    private func save() {
        defaults.set(interfaceLanguage.rawValue, forKey: "interfaceLanguage")
        defaults.set(panelWidth, forKey: "panelWidth")
        defaults.set(compactExtraWidth, forKey: "compactExtraWidth")
        defaults.set(compactExtraHeight, forKey: "compactExtraHeight")
        defaults.set(lyricLineCount, forKey: "lyricLineCount")
        defaults.set(accentName, forKey: "accentName")
        defaults.set(animations, forKey: "animations")
        defaults.set(preferJapaneseLyrics, forKey: "preferJapaneseLyrics")
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
