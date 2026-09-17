import Foundation

public struct LyricsQuery: Equatable, Codable, Sendable {
    public let title: String
    public let artist: String
    public let duration: Double

    public init(title: String, artist: String, duration: Double) {
        let cleanedArtist = artist.replacingOccurrences(of: #"\s*(- Topic|VEVO|Official(?: Channel)?)$"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let reversedQuote = try! NSRegularExpression(pattern: #"^["“](.+?)["”]\s*-\s*(.+?)\s+(?:MV|Official Music Video)$"#, options: .caseInsensitive)
        let reversedSource = cleanedTitle as NSString
        if let match = reversedQuote.firstMatch(in: cleanedTitle, range: NSRange(location: 0, length: reversedSource.length)) {
            let creditedArtist = reversedSource.substring(with: match.range(at: 2))
            let aliases = creditedArtist.components(separatedBy: CharacterSet(charactersIn: "()（）")).map(Self.normalized)
            if aliases.contains(Self.normalized(cleanedArtist)) {
                cleanedTitle = reversedSource.substring(with: match.range(at: 1))
            }
        }
        let bilingualParts = cleanedTitle.components(separatedBy: " - ")
        if bilingualParts.count == 2 {
            let firstHasJapanese = bilingualParts[0].range(of: #"[\p{Han}\p{Hiragana}\p{Katakana}]"#, options: .regularExpression) != nil
            let secondIsLatin = bilingualParts[1].range(of: #"^[A-Za-z0-9 '\-]+$"#, options: .regularExpression) != nil
            let qualifiers = ["live", "remix", "instrumental", "acoustic", "cover", "version", "edit"]
            let secondWords = bilingualParts[1].lowercased().components(separatedBy: .whitespaces)
            if firstHasJapanese && secondIsLatin && !qualifiers.contains(where: secondWords.contains) {
                cleanedTitle = bilingualParts[1]
            }
        }
        if let prefix = cleanedTitle.range(of: #"^[【\[][^】\]]+[】\]]\s*"#, options: .regularExpression) {
            let label = String(cleanedTitle[prefix]).trimmingCharacters(in: CharacterSet(charactersIn: "【】[] "))
            if Self.normalized(label) == Self.normalized(cleanedArtist) { cleanedTitle.removeSubrange(prefix) }
        }
        if let separator = cleanedTitle.range(of: " - "), Self.normalized(String(cleanedTitle[..<separator.lowerBound])) == Self.normalized(cleanedArtist) {
            cleanedTitle = String(cleanedTitle[separator.upperBound...])
        }
        let quoted = try! NSRegularExpression(pattern: #"^(.+?)\s*["“「『](.+?)["”」』]\s*(.*)$"#)
        let source = cleanedTitle as NSString
        if let match = quoted.firstMatch(in: cleanedTitle, range: NSRange(location: 0, length: source.length)),
           Self.normalized(source.substring(with: match.range(at: 1))) == Self.normalized(cleanedArtist) {
            let song = source.substring(with: match.range(at: 2))
            let suffix = source.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
            let visualLabels = ["", "officialmusicvideo", "officialvideo", "musicvideo", "animespecialver", "animespecialversion"]
            cleanedTitle = visualLabels.contains(Self.normalized(suffix)) ? song : song + " " + suffix
        }
        cleanedTitle = cleanedTitle.replacingOccurrences(of: #"\s*[\(\[【](?:official\s*)?(?:music\s*video|video|audio|lyric(?:s)?(?:\s*video)?|MV|HD|4K)[\)\]】]"#, with: "", options: [.regularExpression, .caseInsensitive])
        cleanedTitle = cleanedTitle.replacingOccurrences(of: #"\s*(?:歌いました|歌ってみた)\s*$"#, with: "", options: .regularExpression)
        self.title = cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.artist = cleanedArtist
        self.duration = duration.rounded()
    }

    public var isSearchable: Bool {
        !title.isEmpty && !artist.isEmpty && duration.isFinite && (1...3600).contains(duration)
    }

    public static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    public func matches(_ record: LyricsRecord) -> Bool {
        guard let recordDuration = record.duration else { return false }
        return recordDuration.isFinite && abs(recordDuration - duration) <= 3
            && Self.normalized(record.trackName) == Self.normalized(title)
            && Self.normalized(record.artistName) == Self.normalized(artist)
    }

    public func bestMatch(in records: [LyricsRecord]) -> LyricsRecord? {
        records.filter(matches).sorted { first, second in
            let firstSynced = first.hasValidSyncedLyrics
            let secondSynced = second.hasValidSyncedLyrics
            if firstSynced != secondSynced { return firstSynced }
            let firstDistance = abs((first.duration ?? 0) - duration)
            let secondDistance = abs((second.duration ?? 0) - duration)
            return firstDistance == secondDistance ? first.id < second.id : firstDistance < secondDistance
        }.first
    }
}

public struct LyricsRecord: Codable, Sendable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let duration: Double?
    public let instrumental: Bool
    public let plainLyrics: String?
    public let syncedLyrics: String?

    public var hasValidSyncedLyrics: Bool {
        guard let syncedLyrics, let duration, syncedLyrics.utf8.count <= 500_000 else { return false }
        let lines = LRCParser.parse(syncedLyrics)
        return lines.count >= 2 && (lines.last?.time ?? .infinity) <= duration + 5
    }
}
