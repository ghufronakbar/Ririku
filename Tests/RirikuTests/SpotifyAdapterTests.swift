import AppKit
import Testing
@testable import Ririku
@testable import RirikuCore

@MainActor
struct SpotifyAdapterTests {
    let identifier = "spotify:track:0123456789012345678901"

    private func track(id: String = "spotify:track:0123456789012345678901", position: Double = 15) -> SpotifyTrack {
        SpotifyTrack(id: id, title: "Song", artist: "Artist", duration: 193, position: position, state: "playing", artwork: "")
    }

    @Test func snapshotMatchesSharedPlaybackPipeline() throws {
        let packet = try JSONSerialization.data(withJSONObject: track().packet(sequence: 1))
        let snapshot = try JSONDecoder().decode(PlaybackSnapshot.self, from: packet)
        #expect(snapshot.isValid)
        #expect(snapshot.duration == 193)
        #expect(snapshot.position == 15)
        #expect(snapshot.capabilities.seek)
        #expect(snapshot.sourceId == "desktop")
        #expect(track(position: 250).packet(sequence: 1)["position"] as? Double == 193)
        #expect(track(position: -1).packet(sequence: 1)["position"] as? Double == 0)
    }

    @Test func decodesDurationInMillisecondsAndPositionInSeconds() throws {
        let result = NSAppleEventDescriptor.list()
        let values = [NSAppleEventDescriptor(string: identifier), .init(string: "Song"), .init(string: "Artist"),
                      .init(int32: 193000), .init(double: 23.5), .init(string: "playing"), .init(string: "")]
        for (index, value) in values.enumerated() { result.insert(value, at: index + 1) }
        let decoded = try #require(SpotifyAdapter.decode(result))
        #expect(decoded.duration == 193)
        #expect(decoded.position == 23.5)
        #expect(SpotifyAdapter.decode(.list()) == nil)
    }

    @Test func sourceSelectionFollowsPlaybackButNotRepeatedSpotifyHeartbeat() throws {
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
        model.automaticSource = false
        browser["sequence"] = 2
        browser["trackId"] = "new"
        model.receive(try JSONSerialization.data(withJSONObject: browser))
        #expect(model.current?.id == "spotify:desktop")
    }

    @Test func unknownContentDoesNotExposeLyricsOrControls() {
        let packet = track(id: "spotify:ad:unknown").packet(sequence: 1)
        #expect(packet["isAdvertisement"] as? Bool == true)
        #expect((packet["capabilities"] as? [String: Bool])?.values.allSatisfy { !$0 } == true)
    }

    @Test func commandsRejectInjectionAndInvalidPositions() {
        for action in ["toggle", "next", "previous", "seek"] {
            let script = SpotifyAdapter.commandScript(trackID: identifier, action: action, position: 30)
            #expect(script?.contains("if id of current track is not") == true)
            #expect(script?.contains("with timeout of 2 seconds") == true)
        }
        #expect(SpotifyAdapter.commandScript(trackID: "\"\nquit", action: "next", position: nil) == nil)
        #expect(SpotifyAdapter.commandScript(trackID: identifier, action: "quit", position: nil) == nil)
        for position in [-1.0, .infinity, .nan] {
            #expect(SpotifyAdapter.commandScript(trackID: identifier, action: "seek", position: position) == nil)
        }
        #expect(SpotifyAdapter.commandScript(trackID: identifier, action: "seek", position: nil) == nil)
    }

    @Test func spotifySurvivesBrowserDisconnectAndUsesOwnLabel() throws {
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
    }

    @Test func scriptsCompileWhenSpotifyIsInstalled() throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil else { return }
        let scripts = [SpotifyAdapter.readScript] + ["toggle", "next", "previous", "seek"].compactMap {
            SpotifyAdapter.commandScript(trackID: identifier, action: $0, position: 30)
        }
        for source in scripts {
            var error: NSDictionary?
            let script = try #require(NSAppleScript(source: source))
            let compiled = script.compileAndReturnError(&error)
            #expect(compiled, "\(String(describing: error))")
        }
    }
}
