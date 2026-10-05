import SwiftUI

/// The wide music widget: the track, its lyrics, the seek bar, and the controls.
struct MusicWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    /// Room the page gives the lyrics, from `PanelGeometry`; 0 hides them.
    let lyricHeight: Double
    let twoRows: Bool
    @State private var scrubbing = false
    @State private var seekPosition = 0.0

    var body: some View {
        VStack(spacing: ExpandedLayout.spacing) {
            HStack(spacing: 12) {
                MusicArtwork(image: music.artwork, accent: model.accent, size: ExpandedLayout.artworkSize)
                trackInfo
                Spacer(minLength: 0)
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                VStack(spacing: ExpandedLayout.spacing) {
                    if lyricHeight > 0 { LyricViews.island(model: model, music: music, twoRows: twoRows).frame(height: lyricHeight) }
                    VStack(spacing: ExpandedLayout.seekLabelSpacing) {
                        Slider(value: Binding(get: { scrubbing ? seekPosition : music.position() }, set: { seekPosition = $0 }),
                               in: 0...max(1, music.current?.snapshot.duration ?? 1), onEditingChanged: { editing in
                            scrubbing = editing
                            if !editing { music.command("seek", position: seekPosition) }
                        })
                        .tint(model.accent)
                        .disabled(!music.canControl || music.current?.snapshot.capabilities.seek != true)
                        .accessibilityLabel(model.t("Playback position"))
                        HStack {
                            Text(playbackTime(scrubbing ? seekPosition : music.position()))
                            Spacer()
                            Text(music.current?.snapshot.duration.map(playbackTime) ?? model.t("LIVE"))
                        }.font(.caption2).monospacedDigit().foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            TransportButtons(model: model, music: music)
            if let error = music.commandError {
                Text(model.t(error)).font(.caption2).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(music.current?.snapshot.title ?? "Ririku").font(.headline).lineLimit(1)
            Text(music.current?.snapshot.artist ?? model.t("Waiting for the browser player")).font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            Text(music.current.map { music.sourceLabel(for: $0.snapshot) } ?? model.t("Not connected")).font(.caption2).foregroundStyle(model.accent).lineLimit(1)
        }
    }
}

/// The small music widget: artwork, title, and the controls, without lyrics or the seek bar.
struct MusicSmallWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        VStack(spacing: MusicWidgetLayout.smallHeaderSpacing) {
            HStack(spacing: 8) {
                MusicArtwork(image: music.artwork, accent: model.accent, size: MusicWidgetLayout.smallArtworkSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(music.current?.snapshot.title ?? "Ririku").font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(music.current?.snapshot.artist ?? model.t("Not connected")).font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            TransportButtons(model: model, music: music, spacing: 4)
            if let error = music.commandError {
                Text(model.t(error)).font(.caption2).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }
}
