import Foundation
import Testing
@testable import Ririku
@testable import RirikuCore

@MainActor
private func makeModel() -> (AppModel, UserDefaults) {
    let defaults = MemoryDefaults()
    defaults.set(false, forKey: "automaticLyrics")
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
        model.music.receive(snapshotData())
        #expect(model.music.sessions.count == 1)
        #expect(model.music.current?.snapshot.sourceId == "tab:1")
        #expect(model.music.trackKey == "YouTube:abc")
        #expect(model.music.canControl)
    }

    @Test("Ignores snapshots that are not newer for the same session")
    func ignoresStaleSequence() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(sequence: 5, position: 50))
        model.music.receive(snapshotData(sequence: 4, position: 10))
        #expect(model.music.current?.snapshot.position == 50)
    }

    @Test("Ignores invalid snapshots and unknown message kinds")
    func ignoresInvalidMessages() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(state: "stopped"))
        model.music.receive(Data(#"{"protocolVersion":2,"kind":"snapshot"}"#.utf8))
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"mystery"}"#.utf8))
        #expect(model.music.sessions.isEmpty)
    }

    @Test("Switches to a tab that starts playing, and a heartbeat does not steal the source")
    func followsNewPlayback() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(tab: 1, session: "s1"))
        model.music.receive(snapshotData(tab: 2, session: "s2", track: "second"))
        #expect(model.music.current?.snapshot.sourceId == "tab:2")
        model.music.receive(snapshotData(tab: 1, session: "s1", sequence: 2))
        #expect(model.music.current?.snapshot.sourceId == "tab:2", "an ongoing player keeps sending heartbeats")
        model.music.receive(snapshotData(tab: 1, session: "s1", sequence: 3, track: "third"))
        #expect(model.music.current?.snapshot.sourceId == "tab:1", "a new track counts as new activity")
    }

    @Test("Manual mode keeps the chosen tab")
    func manualModeLocksTab() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(tab: 1, session: "s1"))
        model.music.automaticSource = false
        model.music.selectedSource = "s1:tab:1"
        model.music.receive(snapshotData(tab: 2, session: "s2", track: "second"))
        #expect(model.music.current?.snapshot.sourceId == "tab:1")
    }

    @Test("Manual mode recovers the same tab after a page refresh")
    func manualModeRestoresSession() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(tab: 1, session: "s1"))
        model.music.automaticSource = false
        model.music.selectedSource = "s1:tab:1"
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"remove","sourceId":"tab:1","sessionId":"s1"}"#.utf8))
        #expect(model.music.current == nil)
        model.music.receive(snapshotData(tab: 1, session: "s1-new"))
        #expect(model.music.current?.snapshot.sessionId == "s1-new")
    }

    @Test("Removing a session and disconnecting clear the panel")
    func clearsOnDisconnect() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData())
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"0.3.0"}"#.utf8))
        #expect(model.music.connectedExtensionVersion == "0.3.0")
        model.music.receive(snapshotData(tab: 2, session: "s2", track: "second"))
        model.music.disconnect()
        #expect(model.music.sessions.isEmpty)
        #expect(model.music.current == nil)
        #expect(model.music.connectedExtensionVersion == nil)
        #expect(!model.music.canControl)
    }

    @Test("Rejects an extension version that is not numeric")
    func validatesExtensionVersion() {
        let (model, _) = makeModel()
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"0.3"}"#.utf8))
        #expect(model.music.connectedExtensionVersion == "0.3")
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"<b>"}"#.utf8))
        #expect(model.music.connectedExtensionVersion == "0.3")
    }

    @Test("Has no track key and no controls during an ad")
    func pausesDuringAdvertisement() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(advertisement: true))
        #expect(model.music.trackKey == nil)
        #expect(!model.music.canControl)
        #expect(model.music.lyricStatus == "Ad · lyrics paused")
    }
}

@MainActor
@Suite("Commands")
struct CommandTests {
    @Test("Sends one command with the current session and track, then waits for an ack")
    func sendsCommand() throws {
        let (model, _) = makeModel()
        var sent: [[String: Any]] = []
        model.music.sendPacket = { data in sent.append(try! JSONSerialization.jsonObject(with: data) as! [String: Any]) }
        model.music.receive(snapshotData())
        model.music.command("toggle")
        #expect(sent.count == 1)
        let packet = try #require(sent.first)
        #expect(packet["kind"] as? String == "command")
        #expect(packet["action"] as? String == "toggle")
        #expect(packet["sessionId"] as? String == "session-1")
        #expect(packet["trackId"] as? String == "abc")
        let commandId = try #require(packet["commandId"] as? String)
        #expect(!model.music.canControl, "a second command waits for the ack")

        model.music.receive(Data("{\"protocolVersion\":1,\"kind\":\"ack\",\"commandId\":\"\(commandId)\",\"ok\":false}".utf8))
        #expect(model.music.commandError != nil)
        #expect(model.t(model.music.commandError!) == "Control failed. Try again from the player tab.")
    }

    @Test("Ignores an ack for another command")
    func ignoresForeignAck() {
        let (model, _) = makeModel()
        model.music.sendPacket = { _ in }
        model.music.receive(snapshotData())
        model.music.command("next")
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"ack","commandId":"other","ok":true}"#.utf8))
        #expect(!model.music.canControl)
        #expect(model.music.commandError == nil)
    }

    @Test("Sends nothing without a source")
    func requiresSource() {
        let (model, _) = makeModel()
        var count = 0
        model.music.sendPacket = { _ in count += 1 }
        model.music.command("toggle")
        #expect(count == 0)
    }
}

@MainActor
@Suite("Preferences and layout")
struct PreferenceTests {
    @Test("Stores the lyric offset per track, clamped to one minute")
    func storesOffsetPerTrack() {
        let (model, defaults) = makeModel()
        model.music.receive(snapshotData())
        model.music.lyricOffset = 1.5
        #expect(model.music.lyricOffset == 1.5)
        model.music.lyricOffset = 500
        #expect(model.music.lyricOffset == 60)
        model.music.lyricOffset = -500
        #expect(model.music.lyricOffset == -60)
        let stored = defaults.dictionary(forKey: "lyricOffsetsByTrack") as? [String: Double]
        #expect(stored?["YouTube:abc"] == -60)
        model.music.receive(snapshotData(sequence: 2, track: "other"))
        #expect(model.music.lyricOffset == 0, "another song starts without an offset")
    }

    @Test("A video plays with the same offset on YouTube and YouTube Music")
    func sharesOffsetBetweenSites() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData())
        model.music.lyricOffset = 2
        model.music.receive(snapshotData(tab: 2, session: "s2", sequence: 1, label: "YouTube Music · Chrome"))
        #expect(model.music.trackKey == "YouTube:abc")
        #expect(model.music.lyricOffset == 2)
    }

    @Test("Saves and restores the interface language and appearance")
    func persistsPreferences() {
        let (model, defaults) = makeModel()
        model.interfaceLanguage = .ja
        model.music.lyricLineCount = 2
        model.compactExtraWidth = 120
        model.compactExtraHeight = 8
        let restored = AppModel(defaults: defaults)
        #expect(restored.interfaceLanguage == .ja)
        #expect(restored.music.lyricLineCount == 2)
        #expect(restored.compactExtraWidth == 120)
        #expect(restored.compactExtraHeight == 8)
    }

    @Test("Sizes the compact island from the notch and keeps it on the screen")
    func computesPanelSize() {
        let (model, _) = makeModel()
        model.notchWidth = 200
        model.topHeight = 34
        #expect(model.panelSize(screenWidth: 1512).width == 200, "idle matches the notch")
        #expect(model.panelSize(screenWidth: 1512).height == 34)
        model.music.receive(snapshotData())
        #expect(model.panelSize(screenWidth: 1512).width == 200, "playing still matches the notch by default")
        #expect(model.panelSize(screenWidth: 1512).height == 34, "and lyrics are the only thing that adds height")
        model.compactExtraWidth = 80
        model.compactExtraHeight = 6
        #expect(model.panelSize(screenWidth: 1512).width == 280)
        #expect(model.panelSize(screenWidth: 1512).height == 40)
        #expect(model.compactIconSize == 24, "a 40 pt island still fits the full artwork")
        model.compactExtraHeight = 0
        model.topHeight = 20
        #expect(model.compactIconSize == 14, "a short island shrinks the artwork instead of overflowing")
        model.topHeight = 34
        model.resetIslandSize()
        #expect(model.panelSize(screenWidth: 1512).width == 200)
        model.expanded = true
        #expect(model.panelSize(screenWidth: 1512).width == 442)
        #expect(model.panelSize(screenWidth: 400).width == 376, "never wider than the screen minus 24 pt")
        #expect(model.panelSize(screenWidth: 1512).height == 199, "the expanded panel is as tall as its rows")
    }

    @Test("The expanded panel adds height only for the rows it draws")
    func measuresExpandedContent() {
        let (model, _) = makeModel()
        model.topHeight = 34
        model.expanded = true
        model.music.receive(snapshotData())
        let bare = model.panelSize(screenWidth: 1512).height
        #expect(bare == 199, "12 + 48 + 12 + 20 + 2 + 13 + 12 + 32 + 14 rows plus the 34 pt strip")
        model.music.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]first\n[00:10]second\n")
        model.music.lyricLineCount = 3
        #expect(model.islandLyricHeight == 74)
        #expect(model.panelSize(screenWidth: 1512).height == bare + 86)
        model.music.lyricLineCount = 1
        #expect(model.panelSize(screenWidth: 1512).height == bare + 46, "fewer lyric lines shorten the panel")
        model.music.showLyrics = false
        model.music.commandError = UIText("Control failed. Try again from the player tab.")
        #expect(model.panelSize(screenWidth: 1512).height == bare + 38, "an error gets its own row instead of borrowing slack")
    }

    @Test("Keeps artwork and spectrum while paused but hides the lyrics")
    func hidesLyricsWhilePaused() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(position: 10))
        model.music.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]first\n[00:10]second\n")
        #expect(model.music.isPlayingNow)
        #expect(model.islandLyricHeight > 0)
        let playingHeight = model.panelSize(screenWidth: 1512).height
        model.music.receive(snapshotData(sequence: 2, state: "paused", position: 10))
        #expect(!model.music.isPlayingNow)
        #expect(model.music.current != nil, "the artwork and the spectrum stay")
        #expect(model.islandLyricHeight == 0)
        #expect(model.panelSize(screenWidth: 1512).height < playingHeight)
        model.expanded = true
        #expect(model.islandLyricHeight > 0, "the expanded panel keeps showing lyrics while paused")
    }

    @Test("Shows the configured number of lyric lines around the active one")
    func buildsLyricRows() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(position: 10))
        model.music.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]first\n[00:10]second\n[00:20]third\n")
        model.music.lyricLineCount = 1
        #expect(model.music.displayedLyricRows().map(\.text) == ["second"])
        model.music.lyricLineCount = 2
        #expect(model.music.displayedLyricRows().map(\.text) == ["second", "third"])
        model.music.lyricLineCount = 3
        #expect(model.music.displayedLyricRows().map(\.text) == ["first", "second", "third"])
        #expect(model.music.displayedLyricRows().map(\.active) == [false, true, false])
        #expect(model.music.lyricStatus == "second")
    }

    @Test("Hides lyrics and status text when the island has no lyrics")
    func reportsIslandLyrics() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData())
        #expect(!model.music.hasIslandLyrics)
        #expect(model.islandLyricHeight == 0)
        model.music.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]line\n")
        #expect(model.music.hasIslandLyrics)
        #expect(model.islandLyricHeight > 0)
        model.music.showLyrics = false
        #expect(!model.music.hasIslandLyrics)
        #expect(model.islandLyricHeight == 0)
    }

    @Test("Translates the demo source label but leaves service labels alone")
    func localizesDemoLabel() {
        let (model, _) = makeModel()
        model.music.demo = true
        let demo = try! #require(model.music.current?.snapshot)
        #expect(model.music.sourceLabel(for: demo) == "Local demo")
        model.music.receive(snapshotData())
        model.music.demo = false
        let real = try! #require(model.music.current?.snapshot)
        #expect(model.music.sourceLabel(for: real) == "YouTube · Chrome")
    }
}

@MainActor
@Suite("Lyric rows in the island")
struct LyricRowTests {
    @Test("Reserves a second row for the active line only when a line does not fit")
    func reservesSecondRow() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(position: 10))
        model.music.lyricLineCount = 3
        model.music.lyrics["YouTube:abc"] = LRCParser.parse(
            "[00:00]Ah ah\n[00:10]I have been searching for a long time and I am looking back now\n")
        #expect(model.lyricTextWidth == 144, "the notch-sized island minus the lyric padding")
        #expect(model.reservesTwoLyricRows)
        #expect(model.lyricBlockHeight == 94)
        model.compactExtraWidth = 440
        #expect(!model.reservesTwoLyricRows, "a wide island fits the line in one row")
        #expect(model.lyricBlockHeight == 74)
    }

    @Test("Leaves captions and songs without lyrics on one row")
    func skipsOtherSources() {
        let (model, _) = makeModel()
        model.music.receive(snapshotData(position: 10, extra: ["captionEnabled": true, "captionText": "a caption line"]))
        #expect(model.music.usesVideoCaption)
        #expect(!model.reservesTwoLyricRows, "captions wrap on their own")
        model.music.showLyrics = false
        #expect(!model.reservesTwoLyricRows)
    }
}

@MainActor
@Suite("General settings")
struct GeneralSettingsTests {
    @Test("Start with the earlier behavior: no Dock icon, a menu bar icon, the same delays, no haptics, no shortcut")
    func keepsEarlierDefaults() {
        let (model, _) = makeModel()
        #expect(!model.showInDock)
        #expect(model.showMenuBarIcon)
        #expect(model.hoverOpenDelay == 0.15)
        #expect(model.hoverCloseDelay == 0.35)
        #expect(!model.hapticFeedback)
        #expect(model.panelShortcut == nil)
        #expect(model.panelDisplayID == nil)
    }

    @Test("Saves and restores the general settings")
    func persistsSettings() {
        let (model, defaults) = makeModel()
        var iconChanges = 0
        model.iconsChanged = { iconChanges += 1 }
        model.showInDock = true
        model.showMenuBarIcon = false
        #expect(iconChanges == 2)
        model.hoverOpenDelay = 0.4
        model.hoverCloseDelay = 1.2
        model.hapticFeedback = true
        model.panelShortcut = HotKey(keyCode: 45, modifiers: HotKey.command | HotKey.option, key: "N")
        model.choosePanelDisplay(id: "display-uuid", name: "Studio Display")
        let restored = AppModel(defaults: defaults)
        #expect(restored.showInDock)
        #expect(!restored.showMenuBarIcon)
        #expect(restored.hoverOpenDelay == 0.4)
        #expect(restored.hoverCloseDelay == 1.2)
        #expect(restored.hapticFeedback)
        #expect(restored.panelShortcut?.label == "⌥⌘N")
        #expect(restored.panelDisplayID == "display-uuid")
        #expect(restored.panelDisplayName == "Studio Display")
        restored.choosePanelDisplay(id: nil, name: "ignored")
        #expect(restored.panelDisplayName == nil, "automatic placement keeps no display name")
    }

    @Test("Ignores stored values that are out of range or unreadable")
    func rejectsInvalidStoredValues() {
        let defaults = MemoryDefaults()
        defaults.set(9.0, forKey: "hoverOpenDelay")
        defaults.set(-1.0, forKey: "hoverCloseDelay")
        defaults.set(Data("not json".utf8), forKey: "panelShortcut")
        let model = AppModel(defaults: defaults)
        #expect(model.hoverOpenDelay == 0.15)
        #expect(model.hoverCloseDelay == 0.35)
        #expect(model.panelShortcut == nil)
        let plain = try! JSONEncoder().encode(HotKey(keyCode: 45, modifiers: 0, key: "N"))
        defaults.set(plain, forKey: "panelShortcut")
        #expect(AppModel(defaults: defaults).panelShortcut == nil, "a shortcut without Command, Option, or Control is dropped")
    }

    @Test("Releases the shortcut while a new one is recorded")
    func reportsShortcutChanges() {
        let (model, _) = makeModel()
        var changes = 0
        model.shortcutChanged = { changes += 1 }
        model.recordingShortcut = true
        model.panelShortcut = HotKey(keyCode: 45, modifiers: HotKey.control, key: "N")
        model.recordingShortcut = false
        #expect(changes == 3)
    }

    @Test("Setup opens where the music is connected until a source is set up")
    func choosesSetupPage() {
        let (model, _) = makeModel()
        #expect(model.defaultSetupPage == .browserConnection)
        model.music.receive(Data(#"{"protocolVersion":1,"kind":"extension","version":"0.3.1"}"#.utf8))
        #expect(model.defaultSetupPage == .general)
    }
}
