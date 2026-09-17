import Foundation
import Testing
@testable import Ririku
@testable import RirikuCore

@MainActor
private func makeModel() -> (AppModel, UserDefaults) {
    let defaults = MemoryDefaults()
    let cache = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-lyrics-\(UUID().uuidString)")
    let model = AppModel(lyricsService: LyricsService(cacheDirectory: cache), defaults: defaults)
    model.interfaceLanguage = .en
    return (model, defaults)
}

private func snapshotData(
    tab: Int = 1, session: String = "session-1", sequence: Int = 1, track: String = "abc",
    state: String = "playing", position: Double = 10, duration: Double? = 200,
    label: String = "YouTube · Chrome", advertisement: Bool = false, extra: [String: Any] = [:]
) -> Data {
    var packet: [String: Any] = [
        "protocolVersion": 1, "kind": "snapshot", "sessionId": session, "sourceId": "tab:\(tab)",
        "sourceLabel": label, "sequence": sequence, "trackId": track, "title": "Song", "artist": "Artist",
        "position": position, "playbackRate": 1, "state": state, "isAdvertisement": advertisement,
        "capabilities": ["playPause": true, "previous": false, "next": true, "seek": true]
    ]
    if let duration { packet["duration"] = duration }
    packet.merge(extra) { _, new in new }
    return try! JSONSerialization.data(withJSONObject: packet)
}

@MainActor
@Suite("Playback sessions and source selection")
struct SourceSelectionTests {
    @Test("Follows the first player that reports playback")
    func selectsIncomingSource() {
        let (model, _) = makeModel()
        model.receive(snapshotData())
        #expect(model.sessions.count == 1)
        #expect(model.current?.snapshot.sourceId == "tab:1")
        #expect(model.trackKey == "YouTube:abc")
        #expect(model.canControl)
    }

    @Test("Ignores snapshots that are not newer for the same session")
    func ignoresStaleSequence() {
        let (model, _) = makeModel()
        model.receive(snapshotData(sequence: 5, position: 50))
        model.receive(snapshotData(sequence: 4, position: 10))
        #expect(model.current?.snapshot.position == 50)
    }

    @Test("Ignores invalid snapshots and unknown message kinds")
    func ignoresInvalidMessages() {
        let (model, _) = makeModel()
        model.receive(snapshotData(state: "stopped"))
        model.receive(Data(#"{"protocolVersion":2,"kind":"snapshot"}"#.utf8))
        model.receive(Data(#"{"protocolVersion":1,"kind":"mystery"}"#.utf8))
        #expect(model.sessions.isEmpty)
    }

    @Test("Switches to a tab that starts playing, and a heartbeat does not steal the source")
    func followsNewPlayback() {
        let (model, _) = makeModel()
        model.receive(snapshotData(tab: 1, session: "s1"))
        model.receive(snapshotData(tab: 2, session: "s2", track: "second"))
        #expect(model.current?.snapshot.sourceId == "tab:2")
        model.receive(snapshotData(tab: 1, session: "s1", sequence: 2))
        #expect(model.current?.snapshot.sourceId == "tab:2", "an ongoing player keeps sending heartbeats")
        model.receive(snapshotData(tab: 1, session: "s1", sequence: 3, track: "third"))
        #expect(model.current?.snapshot.sourceId == "tab:1", "a new track counts as new activity")
    }

    @Test("Manual mode keeps the chosen tab")
    func manualModeLocksTab() {
        let (model, _) = makeModel()
        model.receive(snapshotData(tab: 1, session: "s1"))
        model.automaticSource = false
        model.selectedSource = "s1:tab:1"
        model.receive(snapshotData(tab: 2, session: "s2", track: "second"))
        #expect(model.current?.snapshot.sourceId == "tab:1")
    }

    @Test("Manual mode recovers the same tab after a page refresh")
    func manualModeRestoresSession() {
        let (model, _) = makeModel()
        model.receive(snapshotData(tab: 1, session: "s1"))
        model.automaticSource = false
        model.selectedSource = "s1:tab:1"
        model.receive(Data(#"{"protocolVersion":1,"kind":"remove","sourceId":"tab:1","sessionId":"s1"}"#.utf8))
        #expect(model.current == nil)
        model.receive(snapshotData(tab: 1, session: "s1-new"))
        #expect(model.current?.snapshot.sessionId == "s1-new")
    }

    @Test("Removing a session and disconnecting clear the panel")
    func clearsOnDisconnect() {
        let (model, _) = makeModel()
        model.receive(snapshotData())
        model.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"0.3.0"}"#.utf8))
        #expect(model.connectedExtensionVersion == "0.3.0")
        model.receive(snapshotData(tab: 2, session: "s2", track: "second"))
        model.disconnect()
        #expect(model.sessions.isEmpty)
        #expect(model.current == nil)
        #expect(model.connectedExtensionVersion == nil)
        #expect(!model.canControl)
    }

    @Test("Rejects an extension version that is not numeric")
    func validatesExtensionVersion() {
        let (model, _) = makeModel()
        model.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"0.3"}"#.utf8))
        #expect(model.connectedExtensionVersion == "0.3")
        model.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"<b>"}"#.utf8))
        #expect(model.connectedExtensionVersion == "0.3")
    }

    @Test("Has no track key and no controls during an ad")
    func pausesDuringAdvertisement() {
        let (model, _) = makeModel()
        model.receive(snapshotData(advertisement: true))
        #expect(model.trackKey == nil)
        #expect(!model.canControl)
        #expect(model.lyricStatus == "Ad · lyrics paused")
    }
}

@MainActor
@Suite("Commands")
struct CommandTests {
    @Test("Sends one command with the current session and track, then waits for an ack")
    func sendsCommand() throws {
        let (model, _) = makeModel()
        var sent: [[String: Any]] = []
        model.sendPacket = { data in sent.append(try! JSONSerialization.jsonObject(with: data) as! [String: Any]) }
        model.receive(snapshotData())
        model.command("toggle")
        #expect(sent.count == 1)
        let packet = try #require(sent.first)
        #expect(packet["kind"] as? String == "command")
        #expect(packet["action"] as? String == "toggle")
        #expect(packet["sessionId"] as? String == "session-1")
        #expect(packet["trackId"] as? String == "abc")
        let commandId = try #require(packet["commandId"] as? String)
        #expect(!model.canControl, "a second command waits for the ack")

        model.receive(Data("{\"protocolVersion\":1,\"kind\":\"ack\",\"commandId\":\"\(commandId)\",\"ok\":false}".utf8))
        #expect(model.commandError != nil)
        #expect(model.t(model.commandError!) == "Control failed. Try again from the player tab.")
    }

    @Test("Ignores an ack for another command")
    func ignoresForeignAck() {
        let (model, _) = makeModel()
        model.sendPacket = { _ in }
        model.receive(snapshotData())
        model.command("next")
        model.receive(Data(#"{"protocolVersion":1,"kind":"ack","commandId":"other","ok":true}"#.utf8))
        #expect(!model.canControl)
        #expect(model.commandError == nil)
    }

    @Test("Sends nothing without a source")
    func requiresSource() {
        let (model, _) = makeModel()
        var count = 0
        model.sendPacket = { _ in count += 1 }
        model.command("toggle")
        #expect(count == 0)
    }
}

@MainActor
@Suite("Preferences and layout")
struct PreferenceTests {
    @Test("Stores the lyric offset per track, clamped to one minute")
    func storesOffsetPerTrack() {
        let (model, defaults) = makeModel()
        model.receive(snapshotData())
        model.lyricOffset = 1.5
        #expect(model.lyricOffset == 1.5)
        model.lyricOffset = 500
        #expect(model.lyricOffset == 60)
        model.lyricOffset = -500
        #expect(model.lyricOffset == -60)
        let stored = defaults.dictionary(forKey: "lyricOffsetsByTrack") as? [String: Double]
        #expect(stored?["YouTube:abc"] == -60)
        model.receive(snapshotData(sequence: 2, track: "other"))
        #expect(model.lyricOffset == 0, "another song starts without an offset")
    }

    @Test("A video plays with the same offset on YouTube and YouTube Music")
    func sharesOffsetBetweenSites() {
        let (model, _) = makeModel()
        model.receive(snapshotData())
        model.lyricOffset = 2
        model.receive(snapshotData(tab: 2, session: "s2", sequence: 1, label: "YouTube Music · Chrome"))
        #expect(model.trackKey == "YouTube:abc")
        #expect(model.lyricOffset == 2)
    }

    @Test("Saves and restores the interface language and appearance")
    func persistsPreferences() {
        let (model, defaults) = makeModel()
        model.interfaceLanguage = .ja
        model.lyricLineCount = 2
        model.compactWidth = 420
        let restored = AppModel(defaults: defaults)
        #expect(restored.interfaceLanguage == .ja)
        #expect(restored.lyricLineCount == 2)
        #expect(restored.compactWidth == 420)
    }

    @Test("Keeps the panel within the notch and the screen")
    func computesPanelSize() {
        let (model, _) = makeModel()
        model.notchWidth = 200
        model.topHeight = 34
        #expect(model.panelSize(screenWidth: 1512).width == 200, "idle matches the notch")
        model.receive(snapshotData())
        #expect(model.panelSize(screenWidth: 1512).width == 360)
        model.compactWidth = 280
        #expect(model.panelSize(screenWidth: 1512).width == 300, "never narrower than the notch plus 100 pt")
        model.expanded = true
        #expect(model.panelSize(screenWidth: 1512).width == 442)
        #expect(model.panelSize(screenWidth: 400).width == 376, "never wider than the screen minus 24 pt")
        #expect(model.panelSize(screenWidth: 1512).height > 34)
    }

    @Test("Shows the configured number of lyric lines around the active one")
    func buildsLyricRows() {
        let (model, _) = makeModel()
        model.receive(snapshotData(position: 10))
        model.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]first\n[00:10]second\n[00:20]third\n")
        model.lyricLineCount = 1
        #expect(model.displayedLyricRows().map(\.text) == ["second"])
        model.lyricLineCount = 2
        #expect(model.displayedLyricRows().map(\.text) == ["second", "third"])
        model.lyricLineCount = 3
        #expect(model.displayedLyricRows().map(\.text) == ["first", "second", "third"])
        #expect(model.displayedLyricRows().map(\.active) == [false, true, false])
        #expect(model.lyricStatus == "second")
    }

    @Test("Hides lyrics and status text when the island has no lyrics")
    func reportsIslandLyrics() {
        let (model, _) = makeModel()
        model.receive(snapshotData())
        #expect(!model.hasIslandLyrics)
        #expect(model.islandLyricHeight == 0)
        model.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]line\n")
        #expect(model.hasIslandLyrics)
        #expect(model.islandLyricHeight > 0)
        model.showLyrics = false
        #expect(!model.hasIslandLyrics)
        #expect(model.islandLyricHeight == 0)
    }

    @Test("Translates the demo source label but leaves service labels alone")
    func localizesDemoLabel() {
        let (model, _) = makeModel()
        model.demo = true
        let demo = try! #require(model.current?.snapshot)
        #expect(model.sourceLabel(for: demo) == "Local demo")
        model.receive(snapshotData())
        model.demo = false
        let real = try! #require(model.current?.snapshot)
        #expect(model.sourceLabel(for: real) == "YouTube · Chrome")
    }
}
