import Foundation
import Testing
@testable import Ririku
@testable import RirikuCore

private actor ScriptedLyricsHTTP: HTTPFetching {
    var statuses: [Int]
    var requests: [URL] = []
    let retryAfter: String?
    let emptySearch: Bool

    init(_ statuses: [Int], retryAfter: String? = nil, emptySearch: Bool = false) {
        self.statuses = statuses
        self.retryAfter = retryAfter
        self.emptySearch = emptySearch
    }

    func get(_ url: URL, limit: Int) async throws -> HTTPResult {
        requests.append(url)
        let status = statuses.isEmpty ? 200 : statuses.removeFirst()
        let record: [String: Any] = ["id": 42, "trackName": "Song", "artistName": "Artist", "duration": 224,
                                    "instrumental": false, "syncedLyrics": "[00:01]First\n[00:05]Second"]
        let payload: Any = url.path.hasSuffix("search") ? (emptySearch ? [] : [record]) : record
        return HTTPResult(data: try JSONSerialization.data(withJSONObject: payload), status: status, retryAfter: retryAfter)
    }
}

@Suite("Lyrics service recovery")
struct LyricsServiceTests {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ririku-service-\(UUID().uuidString)")
    }

    @Test("503 retries without caching a false miss, then a positive result is cached")
    func recoversTransientFailure() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let http = ScriptedLyricsHTTP([503, 200, 200])
        let service = LyricsService(client: http, cacheDirectory: root)
        let query = LyricsQuery(title: "Song", artist: "Artist", duration: 224)
        #expect(try await service.resolve(query)?.id == 42)
        #expect(try await service.resolve(query)?.id == 42)
        #expect(await http.requests.count == 3)
    }

    @Test("Search can recover a failed exact endpoint")
    func searchFallbackAfterExactOutage() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let http = ScriptedLyricsHTTP([503, 503, 503, 200])
        let service = LyricsService(client: http, cacheDirectory: root)
        #expect(try await service.resolve(LyricsQuery(title: "Song", artist: "Artist", duration: 224))?.id == 42)
        #expect(await http.requests.count == 4)
    }

    @Test("An outage and an empty search do not become a cached negative result")
    func noNegativeCacheForOutage() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let http = ScriptedLyricsHTTP([503, 503, 503, 200], emptySearch: true)
        let service = LyricsService(client: http, cacheDirectory: root)
        await #expect(throws: (any Error).self) {
            _ = try await service.resolve(LyricsQuery(title: "Song", artist: "Artist", duration: 224))
        }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("Retry-After prevents immediate retry and does not create a cache entry")
    func respectsServerCooldown() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let http = ScriptedLyricsHTTP([503], retryAfter: "60")
        let service = LyricsService(client: http, cacheDirectory: root)
        for _ in 0..<2 {
            await #expect(throws: (any Error).self) {
                _ = try await service.search("Song Artist", duration: 224)
            }
        }
        #expect(await http.requests.count == 1)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("Cancelling retry does not issue another request")
    func cancellationStopsRetry() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let http = ScriptedLyricsHTTP([503, 200])
        let service = LyricsService(client: http, cacheDirectory: root)
        let task = Task { try await service.search("Song", duration: 224) }
        while await http.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        #expect(await http.requests.count == 1)
    }
}

@MainActor
@Suite("Metadata refresh")
struct MetadataRefreshTests {
    @Test("Corrected title with the same video ID updates the search suggestion and cancels old candidates")
    func sameVideoUpdatedMetadata() throws {
        let defaults = MemoryDefaults()
        defaults.set(false, forKey: "automaticLyrics")
        let model = AppModel(defaults: defaults)
        var packet: [String: Any] = ["protocolVersion": 1, "kind": "snapshot", "sessionId": "test", "sourceId": "tab:1", "sourceLabel": "Fixture",
            "sequence": 1, "trackId": "same", "title": "Old", "artist": "Singer", "position": 10, "duration": 224,
            "playbackRate": 1, "state": "playing", "isAdvertisement": false,
            "capabilities": ["playPause": true, "seek": true, "previous": false, "next": true]]
        model.receive(try JSONSerialization.data(withJSONObject: packet))
        let previous = model.lyricSearchIdentity
        #expect(model.suggestedLyricSearch == "Old Singer")
        packet["title"] = "New"
        packet["sequence"] = 2
        model.receive(try JSONSerialization.data(withJSONObject: packet))
        #expect(model.lyricSearchIdentity != previous)
        #expect(model.suggestedLyricSearch == "New Singer")
        #expect(model.current?.snapshot.duration == 224)
        #expect(!model.expanded)
    }
}
