import Foundation

public struct Capabilities: Codable, Sendable {
    public var playPause: Bool
    public var previous: Bool
    public var next: Bool
    public var seek: Bool
}

public struct PlaybackSnapshot: Codable, Sendable {
    public var protocolVersion: Int
    public var kind: String
    public var sessionId: String
    public var sourceId: String
    public var sourceLabel: String
    public var sequence: Int
    public var trackId: String
    public var title: String
    public var artist: String
    public var position: Double
    public var duration: Double?
    public var playbackRate: Double
    public var state: String
    public var isAdvertisement: Bool
    public var capabilities: Capabilities
    public var artworkURL: String?
    public var captionEnabled: Bool?
    public var captionText: String?

    public var isValid: Bool {
        protocolVersion == 1 && kind == "snapshot" && !sessionId.isEmpty
            && !sourceId.isEmpty && !trackId.isEmpty && sequence >= 0
            && position.isFinite && position >= 0
            && playbackRate.isFinite && (0...16).contains(playbackRate)
            && (duration == nil || (duration!.isFinite && duration! > 0))
            && ["playing", "paused", "buffering", "ended"].contains(state)
            && title.count <= 500 && artist.count <= 500
            && (artworkURL?.count ?? 0) <= 2048
            && (captionText?.utf8.count ?? 0) <= 4000
    }

    public func position(at now: TimeInterval, receivedAt: TimeInterval, staleAfter: TimeInterval = 5) -> Double {
        let elapsed = max(0, now - receivedAt)
        let advance = state == "playing" && !isAdvertisement ? min(elapsed, staleAfter) * playbackRate : 0
        return min(duration ?? .greatestFiniteMagnitude, position + advance)
    }
}

public struct LyricLine: Equatable, Sendable {
    public let time: Double
    public let text: String
}

public enum LRCParser {
    public static func displayLines(_ lines: [LyricLine], preferJapanese: Bool) -> [LyricLine] {
        guard preferJapanese, lines.contains(where: { $0.text.range(of: #"[\p{Hiragana}\p{Katakana}]"#, options: .regularExpression) != nil }) else { return lines }
        let japaneseTimes = Set(lines.filter {
            $0.text.range(of: #"[\p{Hiragana}\p{Katakana}\p{Han}]"#, options: .regularExpression) != nil
        }.map(\.time))
        return lines.filter { line in
            guard japaneseTimes.contains(line.time), !line.text.isEmpty else { return true }
            return line.text.range(of: #"^[\p{Latin}\p{N}\p{P}\p{Z}\p{M}\s]+$"#, options: .regularExpression) == nil
        }
    }

    public static func parse(_ text: String) -> [LyricLine] {
        let stamp = try! NSRegularExpression(pattern: #"\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"\[offset:([+-]?\d+)\]"#, options: .caseInsensitive)
        let entire = text as NSString
        var offset = 0.0
        for match in offsetPattern.matches(in: text, range: NSRange(location: 0, length: entire.length)) {
            offset = (Double(entire.substring(with: match.range(at: 1))) ?? 0) / 1000
        }
        var lines: [LyricLine] = []
        for row in text.components(separatedBy: .newlines) {
            let source = row as NSString
            let matches = stamp.matches(in: row, range: NSRange(location: 0, length: source.length))
            guard let last = matches.last else { continue }
            let lyric = source.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(source.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(source.substring(with: match.range(at: 2))) ?? 0
                let fractionRange = match.range(at: 3)
                let fraction = fractionRange.location == NSNotFound ? 0 : (Double("0." + source.substring(with: fractionRange)) ?? 0)
                lines.append(LyricLine(time: max(0, minutes * 60 + seconds + fraction - offset), text: lyric))
            }
        }
        return lines.enumerated().sorted { first, second in
            first.element.time == second.element.time ? first.offset < second.offset : first.element.time < second.element.time
        }.map(\.element)
    }

    public static func activeIndex(in lines: [LyricLine], position: Double, offset: Double) -> Int? {
        let effective = position - offset
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lines[middle].time <= effective { lower = middle + 1 } else { upper = middle }
        }
        return lower > 0 ? lower - 1 : nil
    }
}
