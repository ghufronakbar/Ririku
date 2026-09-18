import AppKit
import RirikuCore

struct SpotifyTrack: Sendable {
    let id: String
    let title: String
    let artist: String
    let duration: Double
    let position: Double
    let state: String
    let artwork: String

    var isSong: Bool { id.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil }

    func packet(sequence: Int) -> [String: Any] {
        ["protocolVersion": 1, "kind": "snapshot", "sessionId": "spotify", "sourceId": "desktop",
         "sourceLabel": "Spotify", "sequence": sequence, "trackId": id,
         "title": String(title.prefix(500)), "artist": String(artist.prefix(500)),
         "duration": duration, "position": min(duration, max(0, position)), "playbackRate": 1,
         "state": state, "isAdvertisement": !isSong,
         "artworkURL": artwork,
         "capabilities": ["playPause": isSong, "previous": isSong, "next": isSong, "seek": isSong]]
    }
}

private enum SpotifyResult: Sendable {
    case track(SpotifyTrack), empty, failed(Int)
}

@MainActor
final class SpotifyAdapter {
    var onPacket: ((Data) -> Void)?
    var onStatus: ((UIText) -> Void)?
    private let queue = DispatchQueue(label: "ririku.spotify", qos: .utility)
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var sequence = 0

    nonisolated static let readScript = """
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
    """

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
                if NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty {
                    self.remove()
                    self.onStatus?(UIText("Open Spotify and play a song."))
                } else {
                    let result = await self.read()
                    guard !Task.isCancelled, token == self.generation else { return }
                    switch result {
                    case .track(let track):
                        self.sequence += 1
                        self.emit(track.packet(sequence: self.sequence))
                        self.onStatus?(UIText("Spotify connected"))
                    case .empty:
                        self.remove()
                        self.onStatus?(UIText("Open Spotify and play a song."))
                    case .failed(let code):
                        self.remove()
                        self.onStatus?(UIText("Spotify unavailable (%@). Allow Ririku in System Settings → Privacy & Security → Automation, then reconnect.", String(code)))
                        if code == -1743 { return }
                    }
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    private func read() async -> SpotifyResult {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: Self.readScript) else {
                    continuation.resume(returning: .failed(-1)); return
                }
                let result = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(returning: .failed(error[NSAppleScript.errorNumber] as? Int ?? -1)); return
                }
                continuation.resume(returning: Self.decode(result).map(SpotifyResult.track) ?? .empty)
            }
        }
    }

    nonisolated static func decode(_ result: NSAppleEventDescriptor) -> SpotifyTrack? {
        guard result.numberOfItems == 7, let id = result.atIndex(1)?.stringValue, !id.isEmpty else { return nil }
        let duration = (result.atIndex(4)?.doubleValue ?? 0) / 1000
        let position = result.atIndex(5)?.doubleValue ?? 0
        guard duration.isFinite, duration > 0, position.isFinite else { return nil }
        return SpotifyTrack(id: id, title: result.atIndex(2)?.stringValue ?? "",
                            artist: result.atIndex(3)?.stringValue ?? "", duration: duration, position: position,
                            state: result.atIndex(6)?.stringValue == "playing" ? "playing" : "paused",
                            artwork: result.atIndex(7)?.stringValue ?? "")
    }

    nonisolated static func commandScript(trackID: String, action: String, position: Double?) -> String? {
        guard trackID.range(of: #"^spotify:track:[A-Za-z0-9]{22}$"#, options: .regularExpression) != nil else { return nil }
        let instruction: String
        switch action {
        case "toggle": instruction = "playpause"
        case "next": instruction = "next track"
        case "previous": instruction = "previous track"
        case "seek":
            guard let position, position.isFinite, position >= 0 else { return nil }
            instruction = "if \(position) > (duration of current track) / 1000 then return false\nset player position to \(position)"
        default: return nil
        }
        return """
        with timeout of 2 seconds
            if application id "com.spotify.client" is not running then return false
            tell application id "com.spotify.client"
                if id of current track is not "\(trackID)" then return false
                \(instruction)
                return true
            end tell
        end timeout
        """
    }

    func send(_ data: Data) {
        guard task != nil, let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identifier = packet["commandId"] as? String, let track = packet["trackId"] as? String,
              let action = packet["action"] as? String,
              let source = Self.commandScript(trackID: track, action: action, position: packet["position"] as? Double) else { return }
        let token = generation
        Task {
            let ok: Bool = await withCheckedContinuation { continuation in
                queue.async {
                    var error: NSDictionary?
                    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                    continuation.resume(returning: error == nil && result?.booleanValue == true)
                }
            }
            guard token == generation else { return }
            emit(["protocolVersion": 1, "kind": "ack", "commandId": identifier, "ok": ok])
        }
    }

    private func emit(_ packet: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: packet) { onPacket?(data) }
    }

    private func remove() {
        emit(["protocolVersion": 1, "kind": "remove", "sessionId": "spotify", "sourceId": "desktop"])
    }
}
