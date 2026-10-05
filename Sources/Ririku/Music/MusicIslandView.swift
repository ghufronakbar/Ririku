import SwiftUI

/// The compact island: artwork and the spectrum beside the notch, and lyrics below it while music plays.
/// The expanded panel is `ExpandedPanelView`.
struct MusicIslandView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if music.current != nil { MusicArtwork(image: music.artwork, accent: model.accent, size: model.compactIconSize) }
                Spacer(minLength: 0)
                if music.current != nil {
                    DecorativeSpectrum(size: model.compactIconSize,
                                        playing: music.isPlayingNow,
                                        animate: model.canAnimate, color: model.accent,
                                        playingLabel: model.t("Music playing · decorative spectrum"),
                                        pausedLabel: model.t("Music paused or stopped"),
                                        helpText: model.t("Decorative spectrum, not audio analysis"))
                }
            }
            .padding(.horizontal, 6)
            .frame(height: model.islandHeight)
            .fixedSize(horizontal: false, vertical: true)
            if model.islandLyricHeight > 0 && music.current != nil {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    LyricViews.island(model: model, music: music, twoRows: model.reservesTwoLyricRows)
                        .padding(.horizontal, LyricRowLayout.compactPadding).frame(height: model.islandLyricHeight)
                }
            }
        }
    }
}
