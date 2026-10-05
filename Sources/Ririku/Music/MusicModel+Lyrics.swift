import AppKit
import UniformTypeIdentifiers
import RirikuCore

/// Lyrics for the current track: the lines to display and the room they need in the island,
/// the automatic LRCLIB search, manual search and import, and the short "not found" notice.
extension MusicModel {
    var lyricSearchIdentity: String? {
        guard let key = trackKey, let snapshot = current?.snapshot else { return nil }
        return [key, snapshot.title, snapshot.artist].joined(separator: "\u{1F}")
    }

    var suggestedLyricSearch: String {
        guard let snapshot = current?.snapshot else { return "" }
        let query = LyricsQuery(title: snapshot.title, artist: snapshot.artist, duration: snapshot.duration ?? 0)
        return [query.title, query.artist].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var lyricOffset: Double {
        get { trackKey.flatMap { lyricOffsets[$0] } ?? 0 }
        set {
            guard let key = trackKey, newValue.isFinite else { return }
            lyricOffsets[key] = min(60, max(-60, newValue))
            defaults.set(lyricOffsets, forKey: "lyricOffsetsByTrack")
        }
    }

    // MARK: Display

    var usesVideoCaption: Bool {
        lyricSource != "lrclib" && (lyricSource == "caption" || currentLines.isEmpty)
            && current?.snapshot.captionEnabled == true && current?.snapshot.isAdvertisement == false
    }

    var currentLines: [LyricLine] {
        guard lyricSource != "caption", let key = trackKey else { return [] }
        if let cached = displayLineCache[key] { return cached }
        let prepared = LRCParser.displayLines(lyrics[key] ?? [], preferJapanese: preferJapaneseLyrics)
        displayLineCache[key] = prepared
        return prepared
    }

    var currentPlainLyrics: String? { lyricSource == "caption" ? nil : trackKey.flatMap { plainLyrics[$0] } }

    func lyricIndex() -> Int? {
        if usesVideoCaption { return nil }
        return LRCParser.activeIndex(in: currentLines, position: position(), offset: lyricOffset)
    }

    func displayedLyricRows() -> [(text: String, active: Bool)] {
        guard let index = lyricIndex(), !currentLines.isEmpty else { return [(lyricStatus, true)] }
        let offsets = lyricLineCount == 1 ? [0] : lyricLineCount == 2 ? [0, 1] : [-1, 0, 1]
        return offsets.map { offset in
            let target = index + offset
            let text = currentLines.indices.contains(target) ? currentLines[target].text : ""
            return (text.isEmpty ? (offset == 0 ? "♪" : " ") : text, offset == 0)
        }
    }

    var lyricStatus: String {
        guard let current else { return t("Waiting for music in your browser") }
        if current.snapshot.isAdvertisement { return t("Ad · lyrics paused") }
        if usesVideoCaption {
            let caption = current.snapshot.captionText ?? ""
            return caption.isEmpty ? "♪" : caption
        }
        if lyricSource == "caption" { return t("Captions unavailable · turn on CC or choose LRCLIB") }
        if currentLines.isEmpty {
            if let key = trackKey {
                if let message = lyricMessages[key] { return t(message) }
                return automaticLyrics ? t("Searching lyrics…") : t("Automatic lyrics off")
            }
            return t("Lyrics not available yet")
        }
        guard let index = lyricIndex() else { return "♪" }
        return currentLines[index].text.isEmpty ? "♪" : currentLines[index].text
    }

    var hasIslandLyrics: Bool {
        showLyrics && (usesVideoCaption || !currentLines.isEmpty || !(currentPlainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
    }

    var lyricNotice: String? {
        guard showLyrics, !hasIslandLyrics, lyricNoticeKey == trackKey, let lyricNoticeText else { return nil }
        return t(lyricNoticeText)
    }

    // MARK: Layout

    /// True when a line of this song does not fit one row of `width`, so the active line is given two.
    func reservesTwoLyricRows(width: Double) -> Bool {
        guard showLyrics, !usesVideoCaption, let key = trackKey, !currentLines.isEmpty else { return false }
        let cacheKey = "\(key)|\(Int(width.rounded()))"
        if let cached = twoRowCache[cacheKey] { return cached }
        // The active line is the widest of the rows, so it sets the limit.
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let value = LyricLayout.needsTwoRows(currentLines.map(\.text), width: width) { text in
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        twoRowCache[cacheKey] = value
        return value
    }

    /// A translated song adds one row under the active line.
    func lyricBlockHeight(width: Double, translated: Bool = false) -> Double {
        Double(min(3, max(1, lyricLineCount))) * LyricRowLayout.step + 14
            + (reservesTwoLyricRows(width: width) ? LyricRowLayout.step : 0) + (translated ? LyricRowLayout.step : 0)
    }

    /// Lyrics leave the compact island while paused, so it shrinks back to the notch; the expanded panel keeps them.
    /// Translations are shown only in the expanded panel.
    func islandLyricHeight(expanded: Bool, width: Double) -> Double {
        guard expanded || isPlayingNow else { return 0 }
        guard hasIslandLyrics else { return lyricNotice != nil ? 34 : 0 }
        return lyricBlockHeight(width: width, translated: expanded && expandedLyricTranslations != nil)
    }

    // MARK: Translation

    /// The synced lines that lyric translation works on; captions and plain lyrics are not translated.
    var lyricTranslationLines: [String] { usesVideoCaption ? [] : currentLines.map(\.text) }

    /// Identifies the current song's lines and the target language, so a translation never reaches another song.
    var lyricTranslationKey: String? {
        let lines = lyricTranslationLines
        guard let trackKey, !lines.isEmpty else { return nil }
        return [trackKey, lyricTranslator.target, String(lines.joined(separator: "\n").hashValue)].joined(separator: "|")
    }

    /// One translation per line for the expanded panel, empty while they are being made; nil when none are shown.
    var expandedLyricTranslations: [String]? {
        guard showLyrics, lyricTranslator.enabled, let key = lyricTranslationKey, lyricTranslator.expects(key) else { return nil }
        return lyricTranslator.translations(for: key) ?? []
    }

    // MARK: Automatic search

    func refreshLyrics(snapshot: PlaybackSnapshot, key: String, force: Bool) {
        guard !demo, lyricSource != "caption", automaticLyrics, !manualLyrics.contains(key) else { return }
        let query = LyricsQuery(title: snapshot.title, artist: snapshot.artist, duration: snapshot.duration ?? 0)
        let signature = key + ":" + query.title + ":" + query.artist + ":" + String(query.duration)
        guard lyricRequestID != signature || Date() >= lyricRetryAfter else { return }
        lyricTask?.cancel()
        lyricRequestID = signature
        lyricRetryAfter = .distantFuture
        guard query.isSearchable else { lyricMessages[key] = UIText("Waiting for complete song metadata"); return }
        if !force, resolvedQueries[key] == query, lyrics[key]?.isEmpty == false { return }
        lyrics[key] = nil
        plainLyrics[key] = nil
        lyricMessages[key] = UIText("Searching lyrics automatically…")
        lyricTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(650))
                let record = try await self.lyricsService.resolve(query, force: force)
                guard !Task.isCancelled, self.lyricRequestID == signature, self.trackKey == key else { return }
                self.resolvedQueries[key] = query
                self.lyrics[key] = nil
                self.plainLyrics[key] = nil
                guard let record else {
                    if await self.applyEmbeddedLyrics(for: key, signature: signature) { return }
                    self.lyricMessages[key] = UIText("No matching lyrics found yet")
                    self.showMissingLyricsNotice(for: key)
                    return
                }
                self.lyricNames[key] = UIText("LRCLIB · %@ — %@", record.artistName, record.trackName)
                if record.instrumental { self.lyricMessages[key] = UIText("Instrumental · no lyrics") }
                else if record.hasValidSyncedLyrics, let synced = record.syncedLyrics {
                    self.lyrics[key] = LRCParser.parse(synced)
                    self.lyricMessages[key] = UIText("LRCLIB · timestamped (check timing)")
                } else if let plain = record.plainLyrics, !plain.isEmpty {
                    self.plainLyrics[key] = plain
                    self.lyricMessages[key] = UIText("Text lyrics · not synced")
                } else if await self.applyEmbeddedLyrics(for: key, signature: signature) {
                    return
                } else {
                    self.lyricMessages[key] = UIText("Lyrics not available yet")
                    self.showMissingLyricsNotice(for: key)
                }
            } catch {
                guard !Task.isCancelled, self.lyricRequestID == signature, self.trackKey == key else { return }
                self.lyricMessages[key] = UIText("Lyrics service unreachable · retrying automatically")
                self.lyricNames[key] = UIText(error: error)
                self.lyricRetryAfter = Date(timeIntervalSinceNow: 30)
            }
        }
    }

    /// Plain lyrics stored with the track in a desktop app (the Music app), used only when LRCLIB has none.
    private func applyEmbeddedLyrics(for key: String, signature: String) async -> Bool {
        guard let current, let adapter = desktopAdapters[current.id],
              let text = await adapter.embeddedLyrics(for: current.snapshot.trackId),
              !Task.isCancelled, lyricRequestID == signature, trackKey == key else { return false }
        plainLyrics[key] = text
        lyricNames[key] = UIText("Lyrics saved in %@", adapter.player.label)
        lyricMessages[key] = UIText("Text lyrics · not synced")
        return true
    }

    private func showMissingLyricsNotice(for key: String) {
        guard trackKey == key, showLyrics, !hasIslandLyrics, !notifiedMissingTracks.contains(key) else { return }
        notifiedMissingTracks.insert(key)
        lyricNoticeTask?.cancel()
        lyricNoticeKey = key
        lyricNoticeText = UIText("Lyrics not found")
        layoutChanged?()
        lyricNoticeTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, self.lyricNoticeKey == key else { return }
            self.lyricNoticeText = nil
            self.layoutChanged?()
        }
    }

    // MARK: Manual search and import

    func cancelLyricSearch() {
        searchTask?.cancel()
        searchToken = UUID()
        lyricCandidates = []
        lyricSearchBusy = false
        lyricSearchStatus = nil
        candidateTrackKey = nil
        candidateSearchIdentity = nil
    }

    func searchLyrics(_ text: String) {
        cancelLyricSearch()
        guard lyricSource != "caption", let key = trackKey, let duration = current?.snapshot.duration,
              duration.isFinite, duration > 0 else {
            lyricSearchStatus = UIText("Wait for an active song with a known duration.")
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 500 else {
            lyricSearchStatus = UIText("Enter a title or artist, up to 500 characters.")
            return
        }
        let token = searchToken
        candidateTrackKey = key
        candidateSearchIdentity = lyricSearchIdentity
        candidateDuration = duration
        lyricSearchBusy = true
        lyricSearchStatus = UIText("Searching candidates…")
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let records = try await self.lyricsService.search(text, duration: duration)
                guard !Task.isCancelled, self.searchToken == token, self.trackKey == key else { return }
                self.candidateTrackKey = key
                self.candidateDuration = duration
                self.lyricCandidates = records
                self.lyricSearchStatus = records.isEmpty ? UIText("No results. Try another title or alias.")
                    : UIText("Candidates: %@ · sorted by closest duration, not a version guarantee", String(records.count))
            } catch {
                guard !Task.isCancelled, self.searchToken == token, self.trackKey == key else { return }
                self.lyricSearchStatus = UIText(error: error)
            }
            self.lyricSearchBusy = false
        }
    }

    func selectLyrics(_ record: LyricsRecord) {
        guard let key = trackKey, candidateTrackKey == key, candidateSearchIdentity == lyricSearchIdentity, lyricSource != "caption",
              let duration = current?.snapshot.duration, let searchedDuration = candidateDuration,
              abs(duration - searchedDuration) <= 3 else {
            lyricSearchStatus = UIText("Song or duration changed. Search again before choosing.")
            return
        }
        lyricTask?.cancel()
        lyricRequestID = nil
        manualLyrics.insert(key)
        lyrics[key] = record.hasValidSyncedLyrics ? LRCParser.parse(record.syncedLyrics ?? "") : nil
        plainLyrics[key] = record.instrumental ? nil : record.plainLyrics
        lyricNames[key] = UIText("LRCLIB #%@ · %@ — %@", String(record.id), record.artistName, record.trackName)
        lyricMessages[key] = record.instrumental ? UIText("Instrumental")
            : record.hasValidSyncedLyrics ? UIText("LRCLIB · timestamped · chosen manually") : UIText("LRCLIB · text only")
        lyricSearchStatus = UIText("Selected #%@. Check timing; use offset for a constant shift.", String(record.id))
    }

    func importLyrics() {
        guard let key = trackKey else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        panel.message = t("Choose an LRC for the current song. Make sure the recording version matches.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard key == trackKey else { commandError = UIText("The song changed while choosing lyrics. Please try again."); return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_000_000 else { throw BridgeError.system("Lyrics file must be 1 MB or smaller.") }
            let parsed = LRCParser.parse(try String(contentsOf: url, encoding: .utf8))
            guard !parsed.isEmpty else { throw BridgeError.system("No valid LRC timestamps found.") }
            lyricTask?.cancel()
            manualLyrics.insert(key)
            lyrics[key] = parsed
            plainLyrics[key] = nil
            lyricMessages[key] = UIText("Manual LRC")
            lyricNames[key] = UIText("%@", url.lastPathComponent)
            commandError = nil
        } catch { commandError = UIText(error: error) }
    }
}
