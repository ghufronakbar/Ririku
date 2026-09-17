import Foundation
import AppKit
import CryptoKit
import ImageIO
import NotchCore

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
        guard allows(url) else { throw BridgeError.system("Alamat media tidak diizinkan.") }
        var request = URLRequest(url: url)
        request.setValue("NotchBox/0.2.1 (https://github.com/ghufronakbar/notch-box-mac)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, allows(response.url), response.expectedContentLength <= limit else {
            throw BridgeError.system("Respons media tidak valid atau terlalu besar.")
        }
        var data = Data()
        data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
        for try await byte in bytes {
            if data.count >= limit { throw BridgeError.system("Respons media melebihi batas ukuran.") }
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
            .appendingPathComponent("local.notchbox.mac/Lyrics-v1", isDirectory: true)
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
        } else if exact.status != 404 && exact.status != 200 {
            throw BridgeError.system("Layanan lirik belum tersedia (HTTP \(exact.status)).")
        }
        if candidates.first?.hasValidSyncedLyrics != true && candidates.first?.instrumental != true {
            var searchURL = URLComponents(string: "https://lrclib.net/api/search")!
            searchURL.queryItems = parameters
            let search = try await request(searchURL.url!)
            guard search.status == 200 else { throw BridgeError.system("Pencarian lirik gagal (HTTP \(search.status)).") }
            let results = try JSONDecoder().decode([SearchEntry].self, from: search.data)
            candidates.append(contentsOf: results.compactMap(\.record))
        }
        try Task.checkCancellation()
        let result = query.bestMatch(in: candidates)
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
        let wait = nextRequest.timeIntervalSinceNow
        if wait > 5 { throw BridgeError.system("Layanan lirik meminta jeda. Coba lagi dalam \(String(format: "%.0f", ceil(wait))) detik.") }
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        defer { nextRequest = max(nextRequest, Date(timeIntervalSinceNow: 0.35)) }
        let response = try await client.get(url, limit: 2_000_000)
        if response.status == 429 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
            let requestedDelay = response.retryAfter.flatMap(Double.init)
                ?? response.retryAfter.flatMap { formatter.date(from: $0)?.timeIntervalSinceNow }
                ?? 60
            let delay = requestedDelay.isFinite ? max(1, requestedDelay) : 60
            nextRequest = Date(timeIntervalSinceNow: delay)
            throw BridgeError.system("Batas layanan lirik tercapai. Coba lagi dalam \(String(format: "%.0f", ceil(delay))) detik.")
        }
        return response
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
    private let client = SafeHTTPClient(hosts: ["i.ytimg.com", "img.youtube.com", "lh3.googleusercontent.com", "lh4.googleusercontent.com", "lh3.ggpht.com"])

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
