import SwiftUI

struct PrototypePage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        Form {
            Section(model.t("Prototype")) {
                Text(verbatim: "Ririku 0.3.1 · Native macOS").font(.caption).foregroundStyle(.secondary)
                Toggle(model.t("Local demo (no audio)"), isOn: $music.demo)
                Text(model.t("No telemetry or cookies. Song metadata is sent to LRCLIB when automatic search is on; the Search button sends your search terms. Subtitles-only mode does not query LRCLIB. Thumbnails come from YouTube/Google or Spotify image servers."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
