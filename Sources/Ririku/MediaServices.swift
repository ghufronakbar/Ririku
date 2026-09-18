import Foundation
import AppKit
import CryptoKit
import ImageIO
import RirikuCore

struct HTTPResult: Sendable {
    let data: Data
    let status: Int
    let retryAfter: String?
}

protocol HTTPFetching: Sendable {
    func get(_ url: URL, limit: Int) async throws -> HTTPResult
}

final class SafeHTTPClient: NSObject, URLSessionTaskDelegate, HTTPFetching, @unchecked Sendable {
    private let hosts: Set<String>
    private var session: URLSession!

    init(hosts: Set<String>) {
        self.hosts = hosts
        super.init()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private func allows(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, let host = url.host else { return false }
        return hosts.contains(host.lowercased())
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(allows(request.url) ? request : nil)
    }

    func get(_ url: URL, limit: Int) async throws -> HTTPResult {
        guard allows(url) else { throw BridgeError.system("Media address is not allowed.") }
        var request = URLRequest(url: url)
        request.setValue("Ririku/0.3.1 (https://github.com/ghufronakbar/Ririku)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, allows(response.url), response.expectedContentLength <= limit else {
            throw BridgeError.system("Media response is invalid or too large.")
        }
        var data = Data()
        data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
        for try await byte in bytes {
            if data.count >= limit { throw BridgeError.system("Media response exceeds the size limit.") }
            data.append(byte)
        }
        try Task.checkCancellation()
        return HTTPResult(data: data, status: response.statusCode, retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
    }
}

actor LyricsService {
    private struct CacheEntry: Codable {
        let query: LyricsQuery
        let expires: Date
        let record: LyricsRecord?
    }

    private struct SearchEntry: Decodable {
        let record: LyricsRecord?
        init(from decoder: Decoder) throws { record = try? LyricsRecord(from: decoder) }
    }

    private let client: any HTTPFetching
    private let cacheDirectory: URL
    private var busy = false
    private var nextRequest = Date.distantPast

    init(client: any HTTPFetching = SafeHTTPClient(hosts: ["lrclib.net"]), cacheDirectory: URL? = nil) {
        self.client = client
        self.cacheDirectory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("io.github.lanstheprodigy.ririku/Lyrics-v2", isDirectory: true)
    }

    func resolve(_ query: LyricsQuery, force: Bool = false) async throws -> LyricsRecord? {
        guard query.isSearchable else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(query)
        let name = SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()
        let cacheFile = cacheDirectory.appendingPathComponent(name + ".json")
        if !force, let data = try? Data(contentsOf: cacheFile),
           let cached = try? JSONDecoder().decode(CacheEntry.self, from: data), cached.query == query, cached.expires > Date() {
            return cached.record
        }
        let parameters = [URLQueryItem(name: "track_name", value: query.title), URLQueryItem(name: "artist_name", value: query.artist)]
        var exactURL = URLComponents(string: "https://lrclib.net/api/get")!
        exactURL.queryItems = parameters + [URLQueryItem(name: "duration", value: String(Int(query.duration)))]
        let exact = try await request(exactURL.url!)
        var candidates: [LyricsRecord] = []
        if exact.status == 200, let record = try? JSONDecoder().decode(LyricsRecord.self, from: exact.data), query.matches(record) {
            candidates.append(record)
        } else if exact.status != 404 && exact.status != 200 && ![502, 503, 504].contains(exact.status) {
            throw BridgeError.system("Lyrics service unavailable (HTTP %@).", [String(exact.status)])
        }
        if candidates.first?.instrumental != true {
            var searchURL = URLComponents(string: "https://lrclib.net/api/search")!
            searchURL.queryItems = parameters
            do {
                let search = try await request(searchURL.url!)
                guard search.status == 200 else { throw BridgeError.system("Lyrics search failed (HTTP %@).", [String(search.status)]) }
                let results = try JSONDecoder().decode([SearchEntry].self, from: search.data)
                candidates.append(contentsOf: results.compactMap(\.record))
            } catch {
                try Task.checkCancellation()
                if candidates.isEmpty { throw error }
            }
        }
        try Task.checkCancellation()
        let result = query.bestMatch(in: candidates)
        if result == nil && exact.status != 200 && exact.status != 404 {
            throw BridgeError.system("Lyrics service unavailable (HTTP %@).", [String(exact.status)])
        }
        let entry = CacheEntry(query: query, expires: Date(timeIntervalSinceNow: result == nil ? 1800 : 30 * 86400), record: result)
        if let data = try? JSONEncoder().encode(entry) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? data.write(to: cacheFile, options: .atomic)
            pruneCache()
        }
        return result
    }

    private func request(_ url: URL) async throws -> HTTPResult {
        while busy { try await Task.sleep(for: .milliseconds(50)) }
        busy = true
        defer { busy = false }
        defer { nextRequest = max(nextRequest, Date(timeIntervalSinceNow: 0.35)) }
        for attempt in 0...2 {
            try Task.checkCancellation()
            let wait = nextRequest.timeIntervalSinceNow
            if wait > 5 { throw BridgeError.system("Lyrics service asked to pause. Try again in %@ s.", [String(format: "%.0f", ceil(wait))]) }
            if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
            let response = try await client.get(url, limit: 2_000_000)
            let transient = [502, 503, 504].contains(response.status)
            if response.status == 429 || transient {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
                let requestedDelay = response.retryAfter.flatMap(Double.init)
                    ?? response.retryAfter.flatMap { formatter.date(from: $0)?.timeIntervalSinceNow }
                    ?? (response.status == 429 ? 60 : pow(2, Double(attempt)))
                let delay = requestedDelay.isFinite ? max(1, requestedDelay) : 60
                nextRequest = Date(timeIntervalSinceNow: delay)
                if response.status == 429 {
                    throw BridgeError.system("Lyrics service limit reached. Try again in %@ s.", [String(format: "%.0f", ceil(delay))])
                }
                if attempt < 2 { continue }
            }
            return response
        }
        throw BridgeError.system("Lyrics service unavailable (HTTP %@).", ["503"])
    }

    func search(_ text: String, duration: Double) async throws -> [LyricsRecord] {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, term.count <= 500 else { return [] }
        var url = URLComponents(string: "https://lrclib.net/api/search")!
        url.queryItems = [URLQueryItem(name: "q", value: term)]
        let response = try await request(url.url!)
        guard response.status == 200 else { throw BridgeError.system("Lyrics search failed (HTTP %@).", [String(response.status)]) }
        let records = try JSONDecoder().decode([SearchEntry].self, from: response.data).compactMap(\.record)
        try Task.checkCancellation()
        return LyricsQuery(title: term, artist: "", duration: duration).rankedCandidates(in: records)
    }

    private func pruneCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]), files.count > 300 else { return }
        let sorted = files.sorted {
            ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }
        for file in sorted.prefix(files.count - 300) where file.pathExtension == "json" { try? FileManager.default.removeItem(at: file) }
    }
}

@MainActor
final class ArtworkService {
    private let cache = NSCache<NSString, NSImage>()
    private let client = SafeHTTPClient(hosts: ["i.ytimg.com", "img.youtube.com", "lh3.googleusercontent.com", "lh4.googleusercontent.com", "lh3.ggpht.com", "i.scdn.co"])

    init() { cache.countLimit = 40 }

    func image(for address: String) async throws -> NSImage? {
        if let image = cache.object(forKey: address as NSString) { return image }
        guard let url = URL(string: address) else { return nil }
        let result = try await client.get(url, limit: 2_000_000)
        guard result.status == 200, let source = CGImageSourceCreateWithData(result.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 8192, height <= 8192 else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceThumbnailMaxPixelSize: 256,
                                      kCGImageSourceCreateThumbnailWithTransform: true]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: thumbnail, size: .zero)
        cache.setObject(image, forKey: address as NSString)
        return image
    }
}
