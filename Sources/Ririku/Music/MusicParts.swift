import SwiftUI

/// The track's artwork, or a gradient with a note while there is none.
struct MusicArtwork: View {
    let image: NSImage?
    let accent: Color
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size / 5)
                    .fill(LinearGradient(colors: [accent.opacity(0.9), Color(red: 0.18, green: 0.25, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundStyle(.white))
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size / 5)).accessibilityHidden(true)
    }
}

/// Previous, play or pause, and next. Controls the source does not offer are disabled, never faked (R-UI-9).
struct TransportButtons: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    var spacing: Double = ExpandedLayout.transportSpacing

    var body: some View {
        HStack(spacing: spacing) {
            button("backward.end.fill", label: model.t("Previous track"), action: "previous", enabled: music.current?.snapshot.capabilities.previous == true)
            button(music.current?.snapshot.state == "playing" ? "pause.fill" : "play.fill", label: model.t("Play or pause"), action: "toggle", enabled: music.current?.snapshot.capabilities.playPause == true)
            button("forward.end.fill", label: model.t("Next track"), action: "next", enabled: music.current?.snapshot.capabilities.next == true)
        }
    }

    private func button(_ icon: String, label: String, action: String, enabled: Bool) -> some View {
        Button { music.command(action) } label: {
            Image(systemName: icon).font(.system(size: 18)).frame(width: 40, height: ExpandedLayout.transportHeight)
        }.buttonStyle(.plain).disabled(!music.canControl || !enabled).accessibilityLabel(label)
    }
}

/// The lyric lines, captions, plain lyrics, or the "not found" notice. These are functions rather than a view type,
/// so a `TimelineView` that calls them computes the active line again on every tick.
@MainActor
enum LyricViews {
    @ViewBuilder
    static func island(model: AppModel, music: MusicModel, twoRows: Bool) -> some View {
        if let notice = music.lyricNotice {
            Text(notice).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
        } else if music.hasIslandLyrics { block(model: model, music: music, twoRows: twoRows) }
    }

    private static func block(model: AppModel, music: MusicModel, twoRows: Bool) -> some View {
        VStack(spacing: 4) {
            if music.usesVideoCaption {
                Text(music.lyricStatus).foregroundStyle(model.accent).lineLimit(music.lyricLineCount)
                    .help(model.t("Video captions active; previous and next lines are not available from the player."))
            } else if let index = music.lyricIndex(), !music.currentLines.isEmpty {
                ScrollingLyricRows(lines: music.currentLines, activeIndex: index, lineCount: music.lyricLineCount,
                                   animate: model.canAnimate, accent: model.accent, twoRows: twoRows)
                    .id(music.lyricSearchIdentity)
            } else if let plain = music.currentPlainLyrics {
                ScrollView { Text(plain).lineLimit(nil).foregroundStyle(.white.opacity(0.85)).frame(maxWidth: .infinity) }
                    .help(model.t("Text lyrics without timing; there is no active line."))
            } else { Text(music.lyricStatus).foregroundStyle(.white.opacity(0.65)) }
        }.font(.system(size: 13)).lineLimit(1).frame(maxWidth: .infinity)
    }
}

func playbackTime(_ value: Double) -> String {
    let seconds = max(0, Int(value))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
