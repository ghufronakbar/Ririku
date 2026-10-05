import SwiftUI

struct MusicSourcePage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        Form {
            Section(model.t("Music source")) {
                Toggle(model.t("Automatically follow the active player"), isOn: $music.automaticSource).disabled(music.demo)
                Picker(model.t("Active player"), selection: $music.selectedSource) {
                    Text(model.t("Choose a player tab")).tag("")
                    if !music.selectedSource.isEmpty && music.sessions[music.selectedSource] == nil {
                        Text(model.t("Waiting for the source to reconnect")).tag(music.selectedSource)
                    }
                    ForEach(music.sessions.values.filter { $0.id != "demo:demo" }.sorted { $0.id < $1.id }, id: \.id) { entry in
                        Text(verbatim: "\(music.sourceLabel(for: entry.snapshot)) · \(entry.snapshot.title)").tag(entry.id)
                    }
                }.disabled(music.demo || music.automaticSource)
                Text(model.t("Automatic mode follows the tab that starts playing and restores the connection. Turn it off to lock one tab manually."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(model.t("Connect Spotify desktop"), isOn: $music.spotifyEnabled)
                if music.spotifyEnabled {
                    Text(model.t(music.spotifyStatus)).font(.caption).foregroundStyle(.secondary)
                    Button(model.t("Reconnect Spotify")) { music.reconnectSpotify() }
                }
                Toggle(model.t("Connect Apple Music"), isOn: $music.appleMusicEnabled)
                if music.appleMusicEnabled {
                    Text(model.t(music.appleMusicStatus)).font(.caption).foregroundStyle(.secondary)
                    Button(model.t("Reconnect Apple Music")) { music.reconnectAppleMusic() }
                }
                Text(model.t("Spotify and Apple Music need macOS Automation permission. Lyrics use LRCLIB; choose Auto or LRCLIB, not subtitles-only.")).font(.caption).foregroundStyle(.secondary)
                if let error = music.bridgeError { Text(model.t(error)).foregroundStyle(.red) }
            }
        }
    }
}
