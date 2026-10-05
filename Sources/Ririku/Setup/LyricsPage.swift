import SwiftUI
import RirikuCore

struct LyricsPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    @Binding var searchText: String

    var body: some View {
        Form {
            Section(model.t("Lyrics")) {
                Toggle(model.t("Prefer Japanese on shared timestamps"), isOn: $music.preferJapaneseLyrics)
                Text(model.t("Latin lines that share an exact timestamp with Japanese are hidden from display, not deleted. Other-language lines at different times and mixed text stay intact. Turn it off to see every variant, including simultaneous bilingual duets."))
                    .font(.caption).foregroundStyle(.secondary)
                Picker(model.t("Lyrics source"), selection: $music.lyricSource) {
                    Text(model.t("Automatic · LRCLIB, then captions")).tag("auto")
                    Text(model.t("LRCLIB / LRC only")).tag("lrclib")
                    Text(model.t("YouTube subtitles only")).tag("caption")
                }
                Toggle(model.t("Search LRCLIB automatically when the song changes"), isOn: $music.automaticLyrics).disabled(music.lyricSource == "caption")
                Text(lyricSourceStatus).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.t("Back to automatic result")) { music.retryMedia() }.disabled(music.trackKey == nil || !music.automaticLyrics || music.lyricSource == "caption")
                    Button(model.t("Import LRC…")) { music.importLyrics() }.disabled(music.trackKey == nil || music.lyricSource == "caption")
                }
                Text(music.trackKey.flatMap { music.lyricNames[$0] }.map { model.t($0) } ?? model.t("No lyrics selected yet")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Text(model.t("Offset for this song"))
                    Slider(value: Binding(get: { music.lyricOffset }, set: { music.lyricOffset = $0 }), in: -60...60, step: 0.1)
                    Text(model.t("%@ s", seconds(music.lyricOffset, signed: true))).monospacedDigit().frame(width: 72)
                    Button(model.t("Reset")) { music.lyricOffset = 0 }
                }.disabled(music.trackKey == nil || music.lyricSource == "caption" || music.usesVideoCaption)
                HStack {
                    Button(model.t("Earlier by %@ s", seconds(0.1, signed: false))) { music.lyricOffset -= 0.1 }
                    Button(model.t("Later by %@ s", seconds(0.1, signed: false))) { music.lyricOffset += 0.1 }
                }.disabled(music.trackKey == nil || music.lyricSource == "caption" || music.usesVideoCaption)
                Text(model.t("Offset is saved per video or song; positive values delay lyrics, negative values advance them. Not applied to CC. Duration is used to choose candidates, not to stretch timestamps automatically."))
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup(model.t("Search and choose a lyrics version")) {
                    HStack {
                        TextField(model.t("Title, artist, or song alias"), text: $searchText)
                            .onSubmit { music.searchLyrics(searchText) }
                        Button(music.lyricSearchBusy ? model.t("Searching…") : model.t("Search")) { music.searchLyrics(searchText) }
                            .disabled(music.lyricSearchBusy)
                    }
                    Text(model.t("Player duration: %@ · results sorted by smallest duration difference.", durationLabel(music.current?.snapshot.duration)))
                        .font(.caption).foregroundStyle(.secondary)
                    if let status = music.lyricSearchStatus {
                        Text(model.t(status)).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(music.lyricCandidates, id: \.id) { record in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: "\(record.trackName) — \(record.artistName)").font(.callout).lineLimit(2)
                                Text(verbatim: "\(record.albumName ?? model.t("Unknown album")) · #\(record.id)").font(.caption).foregroundStyle(.secondary)
                                Text(verbatim: "\(durationLabel(record.duration)) · \(differenceLabel(record.duration)) · \(recordKind(record))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.t("Use")) { music.selectLyrics(record) }
                                .disabled(!record.instrumental && !record.hasValidSyncedLyrics && (record.plainLyrics?.isEmpty ?? true))
                        }.padding(.vertical, 4)
                    }
                    Text(model.t("Check the artist and recording version. A large difference can mean an intro, live, cover, or different song. Manual choices last while the app is open."))
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(music.lyricSource == "caption" || music.trackKey == nil)
                if let error = music.commandError { Text(model.t(error)).font(.caption).foregroundStyle(.orange) }
            }
            Section(model.t("Lyric translation")) { LyricTranslationSettings(model: model, translator: music.lyricTranslator) }
        }
    }

    private var lyricSourceStatus: String {
        if music.usesVideoCaption { return model.t("Video captions active · following player CC") }
        if music.lyricSource == "caption" { return music.lyricStatus }
        return music.trackKey.flatMap { music.lyricMessages[$0] }.map { model.t($0) } ?? model.t("Lyrics are searched when a song starts playing.")
    }

    private func seconds(_ value: Double, signed: Bool) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)).locale(model.locale)
        return signed ? value.formatted(style.sign(strategy: .always())) : value.formatted(style)
    }

    private func recordKind(_ record: LyricsRecord) -> String {
        record.instrumental ? model.t("Instrumental") : record.hasValidSyncedLyrics ? model.t("Timestamped") : model.t("Text only")
    }

    private func durationLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0, duration < 86400 else { return model.t("unknown") }
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func differenceLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0, let playback = music.current?.snapshot.duration else { return model.t("difference unknown") }
        let difference = seconds(duration - playback, signed: true)
        return abs(duration - playback) > 3 ? model.t("difference %@ s · check version", difference) : model.t("difference %@ s", difference)
    }
}
