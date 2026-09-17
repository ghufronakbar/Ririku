import Testing
@testable import RirikuCore

private func record(
    id: Int = 1, track: String = "unravel", artist: String = "Ado", album: String? = "Album",
    duration: Double? = 200, instrumental: Bool = false, plain: String? = "plain",
    synced: String? = "[00:01]one\n[00:10]two\n"
) -> LyricsRecord {
    LyricsRecord(id: id, trackName: track, artistName: artist, albumName: album, duration: duration,
                 instrumental: instrumental, plainLyrics: plain, syncedLyrics: synced)
}

@Suite("Lyrics query normalization")
struct LyricsQueryTests {
    @Test("Removes uploader suffixes from the artist")
    func cleansArtist() {
        #expect(LyricsQuery(title: "Song", artist: "YOASOBI - Topic", duration: 200).artist == "YOASOBI")
        #expect(LyricsQuery(title: "Song", artist: "AdoVEVO", duration: 200).artist == "Ado")
    }

    @Test("Removes a bracketed artist prefix and a cover suffix")
    func cleansJapaneseVideoTitle() {
        let query = LyricsQuery(title: "【Ado】 unravel 歌いました", artist: "Ado", duration: 200)
        #expect(query.title == "unravel")
    }

    @Test("Removes an artist prefix separated by a dash")
    func removesArtistPrefix() {
        #expect(LyricsQuery(title: "Ado - unravel", artist: "Ado", duration: 200).title == "unravel")
    }

    @Test("Keeps a dash title when the prefix is not the artist")
    func keepsUnrelatedPrefix() {
        #expect(LyricsQuery(title: "Cover - unravel", artist: "Ado", duration: 200).title == "Cover - unravel")
    }

    @Test("Takes the song from a quoted title and drops visual labels")
    func extractsQuotedTitle() {
        #expect(LyricsQuery(title: "Ado “unravel” Official Music Video", artist: "Ado", duration: 200).title == "unravel")
        #expect(LyricsQuery(title: "Ado “unravel” Live", artist: "Ado", duration: 200).title == "unravel Live")
    }

    @Test("Prefers the Latin part of a bilingual title")
    func prefersLatinPartOfBilingualTitle() {
        #expect(LyricsQuery(title: "あの夢をなぞって - Into The Night", artist: "YOASOBI", duration: 200).title == "Into The Night")
    }

    @Test("Keeps a version qualifier instead of treating it as the title")
    func keepsVersionQualifier() {
        #expect(LyricsQuery(title: "アイドル - Live", artist: "YOASOBI", duration: 200).title == "アイドル - Live")
    }

    @Test("Removes decorative label brackets")
    func removesDecorativeLabels() {
        #expect(LyricsQuery(title: "Song (Official Music Video)", artist: "Artist", duration: 200).title == "Song")
        #expect(LyricsQuery(title: "Song [Lyric Video]", artist: "Artist", duration: 200).title == "Song")
    }

    @Test("Rounds the duration and reports what can be searched")
    func reportsSearchable() {
        #expect(LyricsQuery(title: "Song", artist: "Artist", duration: 200.4).duration == 200)
        #expect(LyricsQuery(title: "Song", artist: "Artist", duration: 200).isSearchable)
        #expect(!LyricsQuery(title: "", artist: "Artist", duration: 200).isSearchable)
        #expect(!LyricsQuery(title: "Song", artist: "", duration: 200).isSearchable)
        #expect(!LyricsQuery(title: "Song", artist: "Artist", duration: 0).isSearchable)
        #expect(!LyricsQuery(title: "Song", artist: "Artist", duration: 4000).isSearchable)
    }

    @Test("Normalization ignores case, accents, and punctuation")
    func normalizesText() {
        #expect(LyricsQuery.normalized("Déjà Vu!") == LyricsQuery.normalized("deja  vu"))
    }
}

@Suite("Lyrics candidate matching")
struct LyricsMatchTests {
    private let query = LyricsQuery(title: "unravel", artist: "Ado", duration: 200)

    @Test("Accepts a duration difference of up to three seconds")
    func acceptsCloseDuration() {
        #expect(query.matches(record(duration: 203)))
        #expect(!query.matches(record(duration: 204)))
        #expect(!query.matches(record(duration: nil)))
    }

    @Test("Requires the same title and artist after normalization")
    func requiresSameTrack() {
        #expect(query.matches(record(track: "UNRAVEL", artist: "ado")))
        #expect(!query.matches(record(track: "unravel (Live)")))
        #expect(!query.matches(record(artist: "TK")))
    }

    @Test("Ignores an uploader suffix on the record's artist")
    func ignoresUploaderSuffix() {
        #expect(query.matches(record(artist: "Ado - Topic")))
    }

    @Test("Prefers timed lyrics, then the closest duration, then the lowest id")
    func picksBestMatch() {
        let plainOnly = record(id: 5, duration: 200, synced: nil)
        let syncedFar = record(id: 6, duration: 202)
        let syncedClose = record(id: 7, duration: 201)
        let syncedTie = record(id: 2, duration: 201)
        #expect(query.bestMatch(in: [plainOnly, syncedFar])?.id == 6)
        #expect(query.bestMatch(in: [syncedFar, syncedClose])?.id == 7)
        #expect(query.bestMatch(in: [syncedClose, syncedTie])?.id == 2)
        #expect(query.bestMatch(in: [record(track: "other")]) == nil)
    }

    @Test("Ranks every result by duration difference and puts unknown durations last")
    func ranksCandidates() {
        let ranked = query.rankedCandidates(in: [
            record(id: 1, duration: nil), record(id: 2, duration: 241), record(id: 3, duration: 199)
        ])
        #expect(ranked.map(\.id) == [3, 2, 1])
    }
}

@Suite("Synced lyrics validation")
struct SyncedLyricsTests {
    @Test("Needs at least two timed lines inside the duration")
    func validatesSyncedLyrics() {
        #expect(record().hasValidSyncedLyrics)
        #expect(!record(synced: "[00:01]only one line\n").hasValidSyncedLyrics)
        #expect(!record(synced: "no timestamps at all").hasValidSyncedLyrics)
        #expect(record(duration: 5).hasValidSyncedLyrics, "the last line may end up to five seconds after the duration")
        #expect(!record(duration: 4).hasValidSyncedLyrics)
        #expect(!record(synced: nil).hasValidSyncedLyrics)
        #expect(!record(duration: nil).hasValidSyncedLyrics)
    }

    @Test("Rejects oversized lyrics files")
    func rejectsHugeLyrics() {
        let huge = String(repeating: "[00:01]line\n", count: 50_000)
        #expect(!record(synced: huge).hasValidSyncedLyrics)
    }
}
