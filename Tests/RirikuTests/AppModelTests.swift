import AppKit
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
        #expect(model.panelSize(screenWidth: 1512).width == 518, "Home holds the wide music widget and the system widget")
        #expect(model.panelSize(screenWidth: 400).width == 376, "never wider than the screen minus 24 pt")
        #expect(model.panelSize(screenWidth: 1512).height == 199, "the expanded panel is as tall as its rows")
        model.editLayout { $0.removeWidget(id: "system") }
        #expect(model.panelSize(screenWidth: 1512).width == 442, "music alone keeps the expanded island width")
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

@MainActor
@Suite("Panel tabs and widgets")
struct PanelTabTests {
    @Test("Starts with the standard layout, saves edits, and restores them")
    func persistsLayout() {
        let (model, defaults) = makeModel()
        #expect(model.layout == .standard)
        model.editLayout { layout in
            let page = layout.addPage()!
            layout.moveWidget(id: "system", toTab: page)
            layout.renameTab(id: page, to: "Stats")
        }
        let restored = AppModel(defaults: defaults)
        #expect(restored.layout == model.layout)
        #expect(restored.visibleTabs.map(restored.tabName) == ["Home", "Tray", "Stats"])
        restored.resetLayout()
        #expect(restored.layout == .standard)
    }

    @Test("A stored layout that cannot be read falls back to the standard one")
    func ignoresBrokenLayout() {
        let defaults = MemoryDefaults()
        defaults.set(Data("{broken".utf8), forKey: "panelLayout")
        #expect(AppModel(defaults: defaults).layout == .standard)
    }

    @Test("Names pages by position until they are given a name")
    func namesPages() {
        let (model, _) = makeModel()
        model.editLayout { $0.addPage(); $0.addPage() }
        #expect(model.visibleTabs.map(model.tabName) == ["Home", "Tray", "Page 2", "Page 3"], "pages are numbered among pages only")
        model.editLayout { $0.renameTab(id: "home", to: "  ") }
        #expect(model.tabName(model.visibleTabs[0]) == "Home", "a blank name keeps the default")
    }

    @Test("Opens on the first tab again after the panel closes")
    func resetsSelectedTab() {
        let (model, _) = makeModel()
        var page = ""
        model.editLayout { page = $0.addPage()! }
        model.expanded = true
        model.selectedTabID = page
        #expect(model.currentTab.id == page)
        model.expanded = false
        #expect(model.currentTab.id == "home")
        model.expanded = true
        model.selectedTabID = page
        model.editLayout { $0.removeTab(id: page) }
        #expect(model.currentTab.id == "home", "a removed tab falls back to the first one")
    }

    @Test("Shares the page between widgets and fits the lyrics into the wide music widget")
    func laysOutPage() {
        let (model, _) = makeModel()
        model.notchWidth = 180
        model.topHeight = 34
        model.expanded = true
        let layout = model.expandedLayout(for: model.currentTab, screenWidth: 1512)
        #expect(layout.width == 518)
        #expect(layout.slotWidths["music"] == 312)
        #expect(layout.slotWidths["system"] == 150)
        #expect(layout.showsTabs, "Home and the Tray")
        _ = model.panelSize(screenWidth: 1512)
        #expect(model.lyricTextWidth == 312)
    }

    @Test("Sizes pages by their tallest widget, and widens the panel for many tabs")
    func sizesPages() {
        let (model, _) = makeModel()
        model.notchWidth = 180
        model.topHeight = 34
        model.expanded = true
        var page = ""
        model.editLayout { page = $0.addPage()!; $0.moveWidget(id: "system", toTab: page) }
        let systemPage = model.visibleTabs.first { $0.id == page }!
        #expect(model.expandedLayout(for: systemPage, screenWidth: 1512).height == 34 + 12 + SystemWidgetLayout.height + 14)
        #expect(model.expandedLayout(for: systemPage, screenWidth: 1512).showsTabs)
        model.editLayout { $0.removeWidget(id: "system") }
        let emptyPage = model.visibleTabs.first { $0.id == page }!
        #expect(model.expandedLayout(for: emptyPage, screenWidth: 1512).height == 34 + 12 + PanelMetrics.emptyPageHeight + 14)
        let tray = model.trayTab!
        #expect(model.expandedLayout(for: tray, screenWidth: 1512).height == 34 + 12 + ToolKind.tray.contentHeight + 14)
        #expect(model.expandedLayout(for: tray, screenWidth: 1512).width == 518, "a tool needs three units")
        model.editLayout { $0.setWide(false, forWidget: "music") }
        #expect(model.expandedLayout(for: model.visibleTabs[0], screenWidth: 1512).height == 34 + 12 + MusicWidgetLayout.smallHeight(error: false) + 14)
        model.editLayout { while $0.addPage() != nil {} }
        // Eight tab buttons left of the notch and room for as much on the right: 180 + 2 × (14 + 8 × 28 + 7 × 4).
        #expect(model.expandedLayout(for: model.visibleTabs[0], screenWidth: 1512).width == 712)
    }
}

@MainActor
@Suite("Local widgets")
struct LocalWidgetTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func quietModel() -> (AppModel, UserDefaults) {
        let (model, defaults) = makeModel()
        model.widgets.update { $0.timerSound = false }
        return (model, defaults)
    }

    @Test("A finished countdown settles and shows a notice without opening the panel")
    func finishesCountdown() {
        let (model, _) = quietModel()
        model.widgets.toggleCountdown(now: now)
        #expect(model.widgets.data.countdown.endDate == now.addingTimeInterval(600))
        model.widgets.finishDueTimers(now: now.addingTimeInterval(601))
        #expect(!model.widgets.data.countdown.clock.isRunning)
        #expect(model.widgets.data.countdown.remaining(at: now) == 0)
        #expect(model.notice?.text.key == "Countdown finished")
        #expect(!model.expanded, "a notice never opens the panel (R-UI-3)")
        model.widgets.toggleCountdown(now: now.addingTimeInterval(700))
        #expect(model.widgets.data.countdown.remaining(at: now.addingTimeInterval(700)) == 600, "starting again starts from the full length")
    }

    @Test("A finished focus session moves to a break")
    func finishesFocus() {
        let (model, _) = quietModel()
        model.widgets.togglePomodoro(now: now)
        model.widgets.finishDueTimers(now: now.addingTimeInterval(25 * 60))
        #expect(model.widgets.data.pomodoroState.phase == .shortBreak)
        #expect(!model.widgets.data.pomodoroState.clock.isRunning)
        #expect(model.notice?.text.key == "Focus finished · time for a break")
    }

    @Test("Timers that ended while the app was closed settle quietly")
    func settlesOnLaunch() {
        let defaults = MemoryDefaults()
        let first = WidgetStore(defaults: defaults, now: now)
        first.toggleCountdown(now: now)
        var announced = false
        let second = WidgetStore(defaults: defaults, now: now.addingTimeInterval(3600))
        second.notice = { _, _ in announced = true }
        #expect(!second.data.countdown.clock.isRunning)
        #expect(!announced)
    }

    @Test("The compact island shows a running timer only while no music plays")
    func showsLiveTimer() {
        let (model, _) = quietModel()
        model.notchWidth = 180
        model.topHeight = 32
        #expect(model.liveTimer == nil)
        model.widgets.toggleStopwatch(now: now)
        #expect(model.liveTimer?.kind == .stopwatch)
        #expect(model.panelSize(screenWidth: 1512) == CGSize(width: 180 + 2 * PanelMetrics.liveSideWidth, height: 32))
        model.widgets.toggleCountdown(now: now)
        #expect(model.liveTimer?.kind == .countdown, "a timer with an end comes before the stopwatch")
        model.music.receive(snapshotData())
        #expect(model.liveTimer == nil, "music keeps the island while it plays (R-WID-1)")
        model.music.receive(snapshotData(sequence: 2, state: "paused"))
        #expect(model.liveTimer?.kind == .countdown)
    }

    @Test("A notice widens the compact island and takes the lyrics' place")
    func sizesNotice() {
        let (model, _) = quietModel()
        model.notchWidth = 180
        model.topHeight = 32
        model.music.receive(snapshotData(position: 10))
        model.music.lyrics["YouTube:abc"] = LRCParser.parse("[00:00]first\n[00:10]second\n")
        #expect(model.islandLyricHeight > 0)
        model.showNotice(UIText("Countdown finished"), icon: "timer")
        #expect(model.islandLyricHeight == 0)
        #expect(model.panelSize(screenWidth: 1512) == CGSize(width: 180 + 2 * PanelMetrics.noticeSideWidth, height: 32 + PanelMetrics.noticeHeight))
    }

    @Test("Saves the counter, water, and launchers and restores them")
    func persistsWidgetData() {
        let (model, defaults) = quietModel()
        model.widgets.changeCounter(by: 3)
        model.widgets.changeWater(by: 2, now: now)
        model.widgets.setShortcut("Morning", enabled: true)
        let bookmark = Bookmark.validated(title: "Docs", address: "example.com")!
        model.widgets.addBookmark(bookmark)
        model.widgets.notes = "Buy milk"
        model.widgets.flushNotes()
        let restored = AppModel(defaults: defaults)
        #expect(restored.widgets.data.counter.value == 3)
        #expect(restored.widgets.waterToday(now: now) == 2)
        #expect(restored.widgets.data.shortcuts == ["Morning"])
        #expect(restored.widgets.data.bookmarks == [bookmark])
        #expect(restored.widgets.notes == "Buy milk")
        restored.widgets.setShortcut("Morning", enabled: false)
        restored.widgets.removeBookmark(bookmark)
        #expect(restored.widgets.data.shortcuts.isEmpty)
        #expect(restored.widgets.data.bookmarks.isEmpty)
    }

    @Test("Runs only shortcuts the user turned on")
    func refusesUnknownShortcut() {
        let (model, _) = quietModel()
        model.widgets.runShortcut("Delete Everything")
        #expect(model.notice == nil, "nothing was started, so nothing failed")
    }

    @Test("New widgets fill a card on the page")
    func sizesWidgetPages() {
        let (model, _) = quietModel()
        model.notchWidth = 180
        model.topHeight = 34
        var pageID = ""
        model.editLayout { layout in
            pageID = layout.addPage()!
            for kind in ["clock", "pomodoro", "notes"] { layout.addWidget(kind: kind, wide: false, toTab: pageID) }
        }
        let page = model.visibleTabs.first { $0.id == pageID }!
        #expect(page.widgets.map(\.kind) == ["clock", "pomodoro", "notes"])
        let layout = model.expandedLayout(for: page, screenWidth: 1512)
        #expect(layout.height == 34 + 12 + WidgetCardLayout.height + 14)
        #expect(layout.width == 518, "three small widgets need three units: 22 + 3 × 150 + 2 × 12 + 22")
    }
}

@MainActor
@Suite("System widget readings")
struct SystemReadingTests {
    @Test("Shows the last processor value, marked as earlier, until a new reading arrives")
    func keepsLastProcessorValue() {
        let defaults = MemoryDefaults()
        defaults.set(0.42, forKey: "lastCPUUsage")
        let monitor = SystemMonitor(defaults: defaults)
        #expect(monitor.cpu == 0.42)
        #expect(!monitor.cpuIsCurrent)
        monitor.start()
        #expect(monitor.cpu == 0.42, "starting keeps the last value instead of a blank")
        // The kernel updates the counters about once a second, so a reading arrives within about that.
        let deadline = Date().addingTimeInterval(2.5)
        while !monitor.cpuIsCurrent && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(SystemMonitor.warmUpInterval)) }
        #expect(monitor.cpuIsCurrent, "a reading arrives soon after the widget appears")
        #expect(defaults.object(forKey: "lastCPUUsage") as? Double == monitor.cpu, "and is remembered for next time")
        monitor.stop()
    }

    @Test("Ignores a stored value that is not a share")
    func ignoresInvalidStoredValue() {
        let defaults = MemoryDefaults()
        defaults.set(7.0, forKey: "lastCPUUsage")
        #expect(SystemMonitor(defaults: defaults).cpu == nil)
    }
}

@MainActor
@Suite("Tray and clipboard")
struct TrayClipboardTests {
    private func temporaryFolder() throws -> URL {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("The Tray keeps links, follows moved files, forgets deleted ones, and never deletes a file")
    func keepsFileLinks() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let report = folder.appendingPathComponent("Report.txt")
        let photo = folder.appendingPathComponent("Photo.txt")
        try Data("a".utf8).write(to: report)
        try Data("b".utf8).write(to: photo)
        let defaults = MemoryDefaults()
        let tray = TrayStore(defaults: defaults)
        tray.add([report, photo, report, folder.appendingPathComponent("missing.txt")])
        #expect(tray.items.map(\.name) == ["Report.txt", "Photo.txt"])
        #expect(TrayStore(defaults: defaults).items.count == 2, "the links are saved")

        let moved = folder.appendingPathComponent("Report final.txt")
        try FileManager.default.moveItem(at: report, to: moved)
        try FileManager.default.removeItem(at: photo)
        tray.refresh()
        #expect(tray.items.map(\.name) == ["Report final.txt"], "a moved file is followed and a deleted one forgotten")

        tray.clear()
        #expect(tray.items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: moved.path), "clearing the Tray never deletes the file (R-WID-7)")
    }

    @Test("Clipboard history keeps text and images, skips secrets, and deletes everything when turned off")
    func keepsClipboardHistory() throws {
        let folder = try temporaryFolder().appendingPathComponent("Clipboard", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ririku-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let defaults = MemoryDefaults()
        let clipboard = ClipboardStore(defaults: defaults, pasteboard: pasteboard, folder: folder)

        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)
        clipboard.poll()
        #expect(clipboard.entries.isEmpty, "nothing is read while history is off")

        clipboard.setEnabled(true)
        clipboard.poll()
        #expect(clipboard.entries.isEmpty, "what was already on the clipboard is not taken")
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)
        clipboard.poll()
        #expect(clipboard.entries.map(\.text) == ["hello"])

        pasteboard.clearContents()
        pasteboard.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("secret", forType: .string)
        clipboard.poll()
        #expect(clipboard.entries.map(\.text) == ["hello"], "content marked as secret is skipped (R-WID-6)")

        let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        pasteboard.clearContents()
        pasteboard.setData(image.representation(using: .png, properties: [:]), forType: .png)
        clipboard.poll()
        #expect(clipboard.entries.map(\.kind) == [.image, .text])
        #expect(FileManager.default.fileExists(atPath: clipboard.imageURL(clipboard.entries[0]).path))

        clipboard.copy(clipboard.entries[1])
        clipboard.poll()
        #expect(clipboard.entries.map(\.text) == ["hello", nil], "copying back moves the entry up without a duplicate")
        #expect(pasteboard.string(forType: .string) == "hello")

        #expect(ClipboardStore(defaults: defaults, pasteboard: pasteboard, folder: folder).entries.count == 2, "the history survives a restart")

        clipboard.setEnabled(false)
        #expect(clipboard.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path), "turning history off deletes it")
    }

    @Test("The Clipboard tab exists exactly while clipboard history is on")
    func managesClipboardTab() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = MemoryDefaults()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ririku-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let model = AppModel(defaults: defaults, clipboard: ClipboardStore(defaults: defaults, pasteboard: pasteboard, folder: folder))
        #expect(!model.layout.tabs.contains { $0.kind == PanelTab.clipboardKind })
        model.setClipboardHistory(true)
        #expect(model.layout.tabs.last?.kind == PanelTab.clipboardKind)
        model.resetLayout()
        #expect(model.layout.tabs.map(\.kind) == ["widgets", "tray", "clipboard"], "resetting keeps the tab while history is on")
        model.setClipboardHistory(false)
        #expect(!model.layout.tabs.contains { $0.kind == PanelTab.clipboardKind })
    }
}
