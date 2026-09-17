import SwiftUI
import RirikuCore

struct SetupView: View {
    @ObservedObject var model: AppModel
    @State private var lyricSearchText = ""

    var body: some View {
        Form {
            Section(model.t("Language")) {
                Picker(model.t("Interface language"), selection: $model.interfaceLanguage) {
                    Text(model.t("Follow system (%@)", InterfaceLanguage.nativeName(of: InterfaceLanguage.system.resolvedCode))).tag(InterfaceLanguage.system)
                    ForEach([InterfaceLanguage.en, .id, .ja]) { language in
                        Text(InterfaceLanguage.nativeName(of: language.rawValue)).tag(language)
                    }
                }
                Text(model.t("Changes apply immediately. Song titles, lyrics, captions, and messages from macOS or websites keep their original language."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("Music source")) {
                Toggle(model.t("Automatically follow the active player"), isOn: $model.automaticSource).disabled(model.demo)
                Picker(model.t("Active player"), selection: $model.selectedSource) {
                    Text(model.t("Choose a player tab")).tag("")
                    if !model.selectedSource.isEmpty && model.sessions[model.selectedSource] == nil {
                        Text(model.t("Waiting for the source to reconnect")).tag(model.selectedSource)
                    }
                    ForEach(model.sessions.values.filter { $0.id != "demo:demo" }.sorted { $0.id < $1.id }, id: \.id) { entry in
                        Text(verbatim: "\(entry.snapshot.sourceLabel) · \(entry.snapshot.title)").tag(entry.id)
                    }
                }.disabled(model.demo || model.automaticSource)
                Text(model.t("Automatic mode follows the tab that starts playing and restores the connection. Turn it off to lock one tab manually."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(model.t("Apple Music and Spotify: not implemented yet.")).font(.caption).foregroundStyle(.secondary)
                if let error = model.bridgeError { Text(model.t(error)).foregroundStyle(.red) }
            }
            Section(model.t("Appearance")) {
                HStack {
                    Text(model.t("Compact island width"))
                    Slider(value: $model.compactWidth, in: 280...620, step: 2)
                    Text(verbatim: "\(Int(model.compactWidth)) pt").monospacedDigit().frame(width: 60)
                }
                HStack {
                    Text(model.t("Expanded island width"))
                    Slider(value: $model.panelWidth, in: 360...720, step: 2)
                    Text(verbatim: "\(Int(model.panelWidth)) pt").monospacedDigit().frame(width: 60)
                }
                Text(model.t("Minimum size follows the physical notch. Height adapts to content and line count."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(model.t("Reset size")) { model.compactWidth = 360; model.panelWidth = 442 }
                Picker(model.t("Accent color"), selection: $model.accentName) {
                    Text(model.t("Peach")).tag("Peach")
                    Text(model.t("Lavender")).tag("Lavender")
                    Text(model.t("Neutral")).tag("Netral")
                }
                Toggle(model.t("Smooth panel transitions (ease-in/ease-out)"), isOn: $model.animations)
                Toggle(model.t("Show lyrics in the island"), isOn: $model.showLyrics)
                Picker(model.t("Lyric lines"), selection: $model.lyricLineCount) {
                    Text(model.t("1 · current")).tag(1)
                    Text(model.t("2 · current + next")).tag(2)
                    Text(model.t("3 · previous + current + next")).tag(3)
                }.disabled(!model.showLyrics)
                Text(model.t("Applies to compact and expanded islands. The spectrum is decorative, not audio analysis, and settles when paused or stopped. The animation toggle and Reduce Motion also control it."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("Lyrics")) {
                Toggle(model.t("Prefer Japanese on shared timestamps"), isOn: $model.preferJapaneseLyrics)
                Text(model.t("Latin lines that share an exact timestamp with Japanese are hidden from display, not deleted. Other-language lines at different times and mixed text stay intact. Turn it off to see every variant, including simultaneous bilingual duets."))
                    .font(.caption).foregroundStyle(.secondary)
                Picker(model.t("Lyrics source"), selection: $model.lyricSource) {
                    Text(model.t("Automatic · LRCLIB, then captions")).tag("auto")
                    Text(model.t("LRCLIB / LRC only")).tag("lrclib")
                    Text(model.t("YouTube subtitles only")).tag("caption")
                }
                Toggle(model.t("Search LRCLIB automatically when the song changes"), isOn: $model.automaticLyrics).disabled(model.lyricSource == "caption")
                Text(lyricSourceStatus).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.t("Back to automatic result")) { model.retryMedia() }.disabled(model.trackKey == nil || !model.automaticLyrics || model.lyricSource == "caption")
                    Button(model.t("Import LRC…")) { model.importLyrics() }.disabled(model.trackKey == nil || model.lyricSource == "caption")
                }
                Text(model.trackKey.flatMap { model.lyricNames[$0] }.map { model.t($0) } ?? model.t("No lyrics selected yet")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Text(model.t("Offset for this song"))
                    Slider(value: Binding(get: { model.lyricOffset }, set: { model.lyricOffset = $0 }), in: -60...60, step: 0.1)
                    Text(model.t("%@ s", seconds(model.lyricOffset, signed: true))).monospacedDigit().frame(width: 72)
                    Button(model.t("Reset")) { model.lyricOffset = 0 }
                }.disabled(model.trackKey == nil || model.lyricSource == "caption" || model.usesVideoCaption)
                HStack {
                    Button(model.t("Earlier by %@ s", seconds(0.1, signed: false))) { model.lyricOffset -= 0.1 }
                    Button(model.t("Later by %@ s", seconds(0.1, signed: false))) { model.lyricOffset += 0.1 }
                }.disabled(model.trackKey == nil || model.lyricSource == "caption" || model.usesVideoCaption)
                Text(model.t("Offset is saved per video or song; positive values delay lyrics, negative values advance them. Not applied to CC. Duration is used to choose candidates, not to stretch timestamps automatically."))
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup(model.t("Search and choose a lyrics version")) {
                    HStack {
                        TextField(model.t("Title, artist, or song alias"), text: $lyricSearchText)
                            .onSubmit { model.searchLyrics(lyricSearchText) }
                        Button(model.lyricSearchBusy ? model.t("Searching…") : model.t("Search")) { model.searchLyrics(lyricSearchText) }
                            .disabled(model.lyricSearchBusy)
                    }
                    Text(model.t("Player duration: %@ · results sorted by smallest duration difference.", durationLabel(model.current?.snapshot.duration)))
                        .font(.caption).foregroundStyle(.secondary)
                    if let status = model.lyricSearchStatus {
                        Text(model.t(status)).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(model.lyricCandidates, id: \.id) { record in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: "\(record.trackName) — \(record.artistName)").font(.callout).lineLimit(2)
                                Text(verbatim: "\(record.albumName ?? model.t("Unknown album")) · #\(record.id)").font(.caption).foregroundStyle(.secondary)
                                Text(verbatim: "\(durationLabel(record.duration)) · \(differenceLabel(record.duration)) · \(recordKind(record))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.t("Use")) { model.selectLyrics(record) }
                                .disabled(!record.instrumental && !record.hasValidSyncedLyrics && (record.plainLyrics?.isEmpty ?? true))
                        }.padding(.vertical, 4)
                    }
                    Text(model.t("Check the artist and recording version. A large difference can mean an intro, live, cover, or different song. Manual choices last while the app is open."))
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(model.lyricSource == "caption" || model.trackKey == nil)
                if let error = model.commandError { Text(model.t(error)).font(.caption).foregroundStyle(.orange) }
            }
            Section(model.t("Prototype")) {
                Text(verbatim: "Ririku 0.3.0 · Native macOS").font(.caption).foregroundStyle(.secondary)
                Toggle(model.t("Local demo (no audio)"), isOn: $model.demo)
                Text(model.t("No telemetry or cookies. Song metadata is sent to LRCLIB when automatic search is on; the Search button sends your search terms. Subtitles-only mode does not query LRCLIB. Thumbnails come from YouTube/Google image servers."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .environment(\.locale, model.locale)
        .frame(width: 580, height: 700)
        .onAppear { resetSearch() }
        .onChange(of: model.trackKey) { _, _ in resetSearch() }
    }

    private var lyricSourceStatus: String {
        if model.usesVideoCaption { return model.t("Video captions active · following player CC") }
        if model.lyricSource == "caption" { return model.lyricStatus }
        return model.trackKey.flatMap { model.lyricMessages[$0] }.map { model.t($0) } ?? model.t("Lyrics are searched when a song starts playing.")
    }

    private func resetSearch() {
        model.cancelLyricSearch()
        guard let snapshot = model.current?.snapshot else { lyricSearchText = ""; return }
        lyricSearchText = snapshot.title
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
        guard let duration, duration.isFinite, duration > 0, let playback = model.current?.snapshot.duration else { return model.t("difference unknown") }
        let difference = seconds(duration - playback, signed: true)
        return abs(duration - playback) > 3 ? model.t("difference %@ s · check version", difference) : model.t("difference %@ s", difference)
    }
}
