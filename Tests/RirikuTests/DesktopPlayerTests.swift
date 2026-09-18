import AppKit
import Testing
@testable import Ririku
@testable import RirikuCore

@MainActor
struct DesktopPlayerTests {
    let identifier = "spotify:track:0123456789012345678901"
    let musicIdentifier = "0123456789ABCDEF"

    private func track(id: String = "spotify:track:0123456789012345678901", position: Double = 15,
                       player: DesktopPlayer = .spotify) -> DesktopTrack {
        DesktopTrack(player: player, id: id, title: "Song", artist: "Artist", duration: 193, position: position, state: "playing", artwork: "")
    }

    private func descriptor(_ values: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
        let result = NSAppleEventDescriptor.list()
        for (index, value) in values.enumerated() { result.insert(value, at: index + 1) }
        return result
    }

    @Test func snapshotMatchesSharedPlaybackPipeline() throws {
        let packet = try JSONSerialization.data(withJSONObject: track().packet(sequence: 1))
        let snapshot = try JSONDecoder().decode(PlaybackSnapshot.self, from: packet)
        #expect(snapshot.isValid)
        #expect(snapshot.duration == 193)
        #expect(snapshot.position == 15)
        #expect(snapshot.capabilities.seek)
        #expect(snapshot.sourceId == "desktop")
        #expect(snapshot.artworkURL == nil)
        #expect(track(position: 250).packet(sequence: 1)["position"] as? Double == 193)
        #expect(track(position: -1).packet(sequence: 1)["position"] as? Double == 0)
    }

    @Test func decodesSpotifyDurationInMillisecondsAndPositionInSeconds() throws {
        let values = [NSAppleEventDescriptor(string: identifier), .init(string: "Song"), .init(string: "Artist"),
                      .init(int32: 193000), .init(double: 23.5), .init(string: "playing"), .init(string: "")]
        let decoded = try #require(DesktopPlayer.spotify.decode(descriptor(values)))
        #expect(decoded.duration == 193)
        #expect(decoded.position == 23.5)
        #expect(DesktopPlayer.spotify.decode(.list()) == nil)
    }

    @Test func decodesAppleMusicDurationInSeconds() throws {
        let values = [NSAppleEventDescriptor(string: musicIdentifier), .init(string: "Song"), .init(string: "Artist"),
                      .init(double: 193.4), .init(double: 23.5), .init(string: "paused"), .init(string: "")]
        let decoded = try #require(DesktopPlayer.appleMusic.decode(descriptor(values)))
        #expect(decoded.duration == 193.4)
        #expect(decoded.state == "paused")
        let packet = try JSONSerialization.data(withJSONObject: decoded.packet(sequence: 1))
        let snapshot = try JSONDecoder().decode(PlaybackSnapshot.self, from: packet)
        #expect(snapshot.isValid)
        #expect(snapshot.sessionId == "apple-music")
        #expect(snapshot.sourceLabel == "Apple Music")
        #expect(!snapshot.isAdvertisement)
        // A radio stream has no duration and is not treated as a song.
        let stream = [NSAppleEventDescriptor(string: musicIdentifier), .init(string: "Radio"), .init(string: ""),
                      .null(), .init(double: 5), .init(string: "playing"), .init(string: "")]
        #expect(DesktopPlayer.appleMusic.decode(descriptor(stream)) == nil)
    }

    @Test func sourceSelectionFollowsPlaybackButNotRepeatedDesktopHeartbeat() throws {
        let defaults = MemoryDefaults()
        defaults.set(false, forKey: "automaticLyrics")
        let model = AppModel(defaults: defaults)
        model.receive(try JSONSerialization.data(withJSONObject: track().packet(sequence: 1)))
        var browser = track().packet(sequence: 1)
        browser["sessionId"] = "browser"
        browser["sourceId"] = "tab:1"
        browser["sourceLabel"] = "Fixture"
        model.receive(try JSONSerialization.data(withJSONObject: browser))
        #expect(model.current?.id == "browser:tab:1")
        model.receive(try JSONSerialization.data(withJSONObject: track().packet(sequence: 2)))
        #expect(model.current?.id == "browser:tab:1")
        model.receive(try JSONSerialization.data(withJSONObject: track(id: "spotify:track:abcdefghijklmnopqrstuv").packet(sequence: 3)))
        #expect(model.current?.id == "spotify:desktop")
        model.receive(try JSONSerialization.data(withJSONObject: track(id: musicIdentifier, player: .appleMusic).packet(sequence: 1)))
        #expect(model.current?.id == "apple-music:desktop")
        model.automaticSource = false
        browser["sequence"] = 2
        browser["trackId"] = "new"
        model.receive(try JSONSerialization.data(withJSONObject: browser))
        #expect(model.current?.id == "apple-music:desktop")
    }

    @Test func unknownContentDoesNotExposeLyricsOrControls() {
        let packet = track(id: "spotify:ad:unknown").packet(sequence: 1)
        #expect(packet["isAdvertisement"] as? Bool == true)
        #expect((packet["capabilities"] as? [String: Bool])?.values.allSatisfy { !$0 } == true)
    }

    @Test func commandsRejectInjectionAndInvalidPositions() {
        for (player, trackID) in [(DesktopPlayer.spotify, identifier), (.appleMusic, musicIdentifier)] {
            for action in ["toggle", "next", "previous", "seek"] {
                let script = player.commandScript(trackID: trackID, action: action, position: 30)
                #expect(script?.contains("if \(player.identity) is not \"\(trackID)\"") == true)
                #expect(script?.contains("with timeout of 2 seconds") == true)
            }
            #expect(player.commandScript(trackID: "\"\nquit", action: "next", position: nil) == nil)
            #expect(player.commandScript(trackID: trackID, action: "quit", position: nil) == nil)
            for position in [-1.0, .infinity, .nan] {
                #expect(player.commandScript(trackID: trackID, action: "seek", position: position) == nil)
            }
            #expect(player.commandScript(trackID: trackID, action: "seek", position: nil) == nil)
        }
        #expect(DesktopPlayer.appleMusic.commandScript(trackID: identifier, action: "next", position: nil) == nil)
        #expect(DesktopPlayer.appleMusic.commandScript(trackID: musicIdentifier, action: "seek", position: 12.5)?
            .contains("set player position to 12.500") == true)
        #expect(DesktopPlayer.spotify.artworkScript(trackID: identifier) == nil)
        #expect(DesktopPlayer.appleMusic.artworkScript(trackID: "\"quit") == nil)
    }

    @Test func desktopSessionsSurviveBrowserDisconnectAndUseOwnLabel() throws {
        let defaults = MemoryDefaults()
        defaults.set(false, forKey: "automaticLyrics")
        let model = AppModel(defaults: defaults)
        model.receive(try JSONSerialization.data(withJSONObject: track().packet(sequence: 1)))
        model.connectedBrowser = "Chrome"
        #expect(model.current?.id == "spotify:desktop")
        #expect(model.sourceLabel(for: try #require(model.current?.snapshot)) == "Spotify")
        model.disconnect()
        #expect(model.current?.id == "spotify:desktop")
        #expect(model.trackKey == "Spotify:" + identifier)
        model.receive(try JSONSerialization.data(withJSONObject: track(id: musicIdentifier, player: .appleMusic).packet(sequence: 1)))
        #expect(model.sourceLabel(for: try #require(model.current?.snapshot)) == "Apple Music")
        model.disconnect()
        #expect(model.current?.id == "apple-music:desktop")
        #expect(model.trackKey == "Apple Music:" + musicIdentifier)
    }

    @Test func scriptsCompileWhenAppIsInstalled() throws {
        for (player, trackID) in [(DesktopPlayer.spotify, identifier), (.appleMusic, musicIdentifier)] {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleIdentifier) != nil else { continue }
            let scripts = [player.readScript] + [player.artworkScript(trackID: trackID)].compactMap { $0 }
                + ["toggle", "next", "previous", "seek"].compactMap { player.commandScript(trackID: trackID, action: $0, position: 30) }
            for source in scripts {
                var error: NSDictionary?
                let script = try #require(NSAppleScript(source: source))
                let compiled = script.compileAndReturnError(&error)
                #expect(compiled, "\(player.label): \(String(describing: error))")
            }
        }
    }
}
