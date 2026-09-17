import Testing
@testable import RirikuCore

private func snapshot(
    state: String = "playing", position: Double = 10, duration: Double? = 200,
    rate: Double = 1, advertisement: Bool = false, title: String = "Song",
    protocolVersion: Int = 1, kind: String = "snapshot", sessionId: String = "session",
    sourceId: String = "tab:1", trackId: String = "abc", sequence: Int = 1,
    artworkURL: String? = nil, captionText: String? = nil
) -> PlaybackSnapshot {
    PlaybackSnapshot(
        protocolVersion: protocolVersion, kind: kind, sessionId: sessionId, sourceId: sourceId,
        sourceLabel: "YouTube · Chrome", sequence: sequence, trackId: trackId, title: title,
        artist: "Artist", position: position, duration: duration, playbackRate: rate, state: state,
        isAdvertisement: advertisement,
        capabilities: Capabilities(playPause: true, previous: false, next: true, seek: true),
        artworkURL: artworkURL, captionEnabled: nil, captionText: captionText
    )
}

@Suite("Playback snapshot validation")
struct SnapshotValidationTests {
    @Test("Accepts a complete snapshot")
    func acceptsValidSnapshot() { #expect(snapshot().isValid) }

    @Test("Rejects another protocol version or kind")
    func rejectsWrongEnvelope() {
        #expect(!snapshot(protocolVersion: 2).isValid)
        #expect(!snapshot(kind: "command").isValid)
    }

    @Test("Rejects empty identifiers")
    func rejectsEmptyIdentifiers() {
        #expect(!snapshot(sessionId: "").isValid)
        #expect(!snapshot(sourceId: "").isValid)
        #expect(!snapshot(trackId: "").isValid)
    }

    @Test("Rejects unknown states and out-of-range numbers")
    func rejectsInvalidNumbers() {
        #expect(!snapshot(state: "stopped").isValid)
        #expect(!snapshot(position: -1).isValid)
        #expect(!snapshot(position: .nan).isValid)
        #expect(!snapshot(duration: 0).isValid)
        #expect(!snapshot(rate: 17).isValid)
        #expect(!snapshot(sequence: -1).isValid)
    }

    @Test("Accepts a live stream without duration")
    func acceptsUnknownDuration() { #expect(snapshot(duration: nil).isValid) }

    @Test("Rejects oversized text")
    func rejectsOversizedText() {
        #expect(!snapshot(title: String(repeating: "a", count: 501)).isValid)
        #expect(!snapshot(artworkURL: "https://example.com/" + String(repeating: "a", count: 2048)).isValid)
        #expect(!snapshot(captionText: String(repeating: "あ", count: 1500)).isValid)
    }
}

@Suite("Playback position estimate")
struct PositionTests {
    @Test("Advances while playing at the playback rate")
    func advancesWhilePlaying() {
        #expect(snapshot().position(at: 102, receivedAt: 100) == 12)
        #expect(snapshot(rate: 2).position(at: 102, receivedAt: 100) == 14)
    }

    @Test("Stops advancing after the stale limit")
    func capsAtStaleLimit() {
        #expect(snapshot().position(at: 200, receivedAt: 100) == 15)
        #expect(snapshot().position(at: 200, receivedAt: 100, staleAfter: 1) == 11)
    }

    @Test("Holds the position when paused, buffering, ended, or during an ad")
    func holdsWhenNotPlaying() {
        #expect(snapshot(state: "paused").position(at: 105, receivedAt: 100) == 10)
        #expect(snapshot(state: "buffering").position(at: 105, receivedAt: 100) == 10)
        #expect(snapshot(state: "ended").position(at: 105, receivedAt: 100) == 10)
        #expect(snapshot(advertisement: true).position(at: 105, receivedAt: 100) == 10)
    }

    @Test("Never goes past the duration and never goes backwards")
    func staysWithinBounds() {
        #expect(snapshot(position: 199, duration: 200).position(at: 103, receivedAt: 100) == 200)
        #expect(snapshot().position(at: 99, receivedAt: 100) == 10)
    }
}
