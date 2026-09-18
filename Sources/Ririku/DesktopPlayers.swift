import AppKit
import RirikuCore

/// A desktop music app that Ririku reads and controls through its local AppleScript dictionary.
struct DesktopPlayer: Sendable {
    let bundleIdentifier: String
    let sessionId: String
    let label: String
    /// A track identifier that is safe to embed in a script and names a song rather than an ad or episode.
    let trackPattern: String
    /// The AppleScript expression for the current track's identifier.
    let identity: String
    /// The AppleScript expression for the current track's duration in seconds.
    let durationInSeconds: String
    /// Multiplier from the duration returned by `readScript` to seconds.
    let durationScale: Double
    let readScript: String
    let supportsArtworkData: Bool
    let idleStatus: UIText
    let connectedStatus: UIText
    let failedStatus: @Sendable (Int) -> UIText

    var id: String { sessionId + ":desktop" }

    static let spotify = DesktopPlayer(
        bundleIdentifier: "com.spotify.client", sessionId: "spotify", label: "Spotify",
        trackPattern: #"^spotify:track:[A-Za-z0-9]{22}$"#,
        identity: "id of current track", durationInSeconds: "(duration of current track) / 1000", durationScale: 0.001,
        readScript: """
        with timeout of 2 seconds
            if application id "com.spotify.client" is not running then return {}
            tell application id "com.spotify.client"
                if player state is stopped then return {}
                set song to current track
                set songID to id of song
                set songTitle to name of song
                set songArtist to artist of song
                set songDuration to duration of song
                set songArtwork to artwork url of song
                set songPosition to player position
                set songState to player state as text
                if id of current track is not songID then return {}
                return {songID, songTitle, songArtist, songDuration, songPosition, songState, songArtwork}
            end tell
        end timeout
        """,
        supportsArtworkData: false,
        idleStatus: UIText("Open Spotify and play a song."),
        connectedStatus: UIText("Spotify connected"),
        failedStatus: { UIText("Spotify unavailable (%@). Allow Ririku in System Settings → Privacy & Security → Automation, then reconnect.", String($0)) })

    /// Music.app, for both library songs and Apple Music streaming. Radio streams have no duration and are skipped.
    static let appleMusic = DesktopPlayer(
        bundleIdentifier: "com.apple.Music", sessionId: "apple-music", label: "Apple Music",
        trackPattern: #"^[0-9A-F]{16}$"#,
        identity: "persistent ID of current track", durationInSeconds: "duration of current track", durationScale: 1,
        readScript: """
        with timeout of 2 seconds
            if application id "com.apple.Music" is not running then return {}
            tell application id "com.apple.Music"
                if player state is stopped then return {}
                try
                    set nowPlaying to current track
                on error errorMessage number errorNumber
                    if errorNumber is -1728 then return {}
                    error errorMessage number errorNumber
                end try
                set songID to persistent ID of nowPlaying
                set songTitle to name of nowPlaying
                set songArtist to artist of nowPlaying
                set songDuration to duration of nowPlaying
                set songPosition to player position
                set songState to player state as text
                if persistent ID of current track is not songID then return {}
                return {songID, songTitle, songArtist, songDuration, songPosition, songState, ""}
            end tell
        end timeout
        """,
        supportsArtworkData: true,
        idleStatus: UIText("Open Music and play a song."),
        connectedStatus: UIText("Apple Music connected"),
        failedStatus: { UIText("Apple Music unavailable (%@). Allow Ririku in System Settings → Privacy & Security → Automation, then reconnect.", String($0)) })

    func isSong(_ trackID: String) -> Bool { trackID.range(of: trackPattern, options: .regularExpression) != nil }

    func decode(_ result: NSAppleEventDescriptor) -> DesktopTrack? {
        guard result.numberOfItems == 7, let id = result.atIndex(1)?.stringValue, !id.isEmpty else { return nil }
        let duration = (result.atIndex(4)?.doubleValue ?? 0) * durationScale
        let position = result.atIndex(5)?.doubleValue ?? 0
        guard duration.isFinite, duration > 0, position.isFinite else { return nil }
        return DesktopTrack(player: self, id: id, title: result.atIndex(2)?.stringValue ?? "",
                            artist: result.atIndex(3)?.stringValue ?? "", duration: duration, position: position,
                            state: result.atIndex(6)?.stringValue == "playing" ? "playing" : "paused",
                            artwork: result.atIndex(7)?.stringValue ?? "")
    }

    func commandScript(trackID: String, action: String, position: Double?) -> String? {
        guard isSong(trackID) else { return nil }
        let instruction: String
        switch action {
        case "toggle": instruction = "playpause"
        case "next": instruction = "next track"
        case "previous": instruction = "previous track"
        case "seek":
            guard let position, position.isFinite, position >= 0 else { return nil }
            let seconds = String(format: "%.3f", position)
            instruction = "if \(seconds) > \(durationInSeconds) then return false\nset player position to \(seconds)"
        default: return nil
        }
        return script(checking: trackID, then: instruction + "\nreturn true", otherwise: "false")
    }

    func artworkScript(trackID: String) -> String? {
        guard supportsArtworkData, isSong(trackID) else { return nil }
        return script(checking: trackID, then: """
            if (count of artworks of current track) is 0 then return missing value
            return raw data of artwork 1 of current track
            """, otherwise: "missing value")
    }

    /// Wraps an instruction so it only runs while the app is open and still on the expected track.
    private func script(checking trackID: String, then body: String, otherwise fallback: String) -> String {
        """
        with timeout of 2 seconds
            if application id "\(bundleIdentifier)" is not running then return \(fallback)
            tell application id "\(bundleIdentifier)"
                if \(identity) is not "\(trackID)" then return \(fallback)
                \(body.replacingOccurrences(of: "\n", with: "\n        "))
            end tell
        end timeout
        """
    }
}

struct DesktopTrack: Sendable {
    let player: DesktopPlayer
    let id: String
    let title: String
    let artist: String
    let duration: Double
    let position: Double
    let state: String
    let artwork: String

    var isSong: Bool { player.isSong(id) }

    func packet(sequence: Int) -> [String: Any] {
        var packet: [String: Any] = [
            "protocolVersion": 1, "kind": "snapshot", "sessionId": player.sessionId, "sourceId": "desktop",
            "sourceLabel": player.label, "sequence": sequence, "trackId": id,
            "title": String(title.prefix(500)), "artist": String(artist.prefix(500)),
            "duration": duration, "position": min(duration, max(0, position)), "playbackRate": 1,
            "state": state, "isAdvertisement": !isSong,
            "capabilities": ["playPause": isSong, "previous": isSong, "next": isSong, "seek": isSong]]
        if !artwork.isEmpty { packet["artworkURL"] = artwork }
        return packet
    }
}

private enum DesktopResult: Sendable {
    case track(DesktopTrack), empty, failed(Int)
}

@MainActor
final class DesktopPlayerAdapter {
    let player: DesktopPlayer
    var onPacket: ((Data) -> Void)?
    var onStatus: ((UIText) -> Void)?
    private let queue: DispatchQueue
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var sequence = 0

    init(player: DesktopPlayer) {
        self.player = player
        queue = DispatchQueue(label: "ririku." + player.sessionId, qos: .utility)
    }

    func setEnabled(_ enabled: Bool) {
        task?.cancel()
        task = nil
        generation = UUID()
        remove()
        guard enabled else { return }
        let token = generation
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, token == self.generation else { return }
                if NSRunningApplication.runningApplications(withBundleIdentifier: self.player.bundleIdentifier).isEmpty {
                    self.remove()
                    self.onStatus?(self.player.idleStatus)
                } else {
                    let result = await self.read()
                    guard !Task.isCancelled, token == self.generation else { return }
                    switch result {
                    case .track(let track):
                        self.sequence += 1
                        self.emit(track.packet(sequence: self.sequence))
                        self.onStatus?(self.player.connectedStatus)
                    case .empty:
                        self.remove()
                        self.onStatus?(self.player.idleStatus)
                    case .failed(let code):
                        self.remove()
                        self.onStatus?(self.player.failedStatus(code))
                        if code == -1743 { return }
                    }
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    private func run(_ source: String) async -> (NSAppleEventDescriptor?, Int?) {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else { continuation.resume(returning: (nil, -1)); return }
                let result = script.executeAndReturnError(&error)
                if let error { continuation.resume(returning: (nil, error[NSAppleScript.errorNumber] as? Int ?? -1)); return }
                continuation.resume(returning: (result, nil))
            }
        }
    }

    private func read() async -> DesktopResult {
        let (result, error) = await run(player.readScript)
        if let error { return .failed(error) }
        return result.flatMap(player.decode).map(DesktopResult.track) ?? .empty
    }

    /// Artwork embedded in the app's track, read locally instead of downloaded.
    func artwork(for trackID: String) async -> NSImage? {
        guard task != nil, let source = player.artworkScript(trackID: trackID) else { return nil }
        let (result, _) = await run(source)
        guard let data = result?.data, !data.isEmpty, data.count <= 10_000_000 else { return nil }
        return ArtworkService.thumbnail(from: data)
    }

    func send(_ data: Data) {
        guard task != nil, let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identifier = packet["commandId"] as? String, let track = packet["trackId"] as? String,
              let action = packet["action"] as? String,
              let source = player.commandScript(trackID: track, action: action, position: packet["position"] as? Double) else { return }
        let token = generation
        Task {
            let (result, error) = await run(source)
            guard token == generation else { return }
            emit(["protocolVersion": 1, "kind": "ack", "commandId": identifier, "ok": error == nil && result?.booleanValue == true])
        }
    }

    private func emit(_ packet: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: packet) { onPacket?(data) }
    }

    private func remove() {
        emit(["protocolVersion": 1, "kind": "remove", "sessionId": player.sessionId, "sourceId": "desktop"])
    }
}
