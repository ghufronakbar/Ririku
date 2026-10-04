import SwiftUI

struct AppearancePage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        Form {
            Section(model.t("Appearance")) {
                HStack {
                    Text(model.t("Compact island width"))
                    Slider(value: Binding(get: { model.compactWidth },
                                          set: { model.compactExtraWidth = max(0, $0 - model.notchWidth) }),
                           in: model.notchWidth...(model.notchWidth + AppModel.compactWidthRange), step: 2)
                    Text(verbatim: "\(Int(model.compactWidth)) pt").monospacedDigit().frame(width: 60)
                }
                HStack {
                    Text(model.t("Compact island height"))
                    Slider(value: Binding(get: { model.topHeight + model.compactExtraHeight },
                                          set: { model.compactExtraHeight = max(0, $0 - model.topHeight) }),
                           in: model.topHeight...(model.topHeight + AppModel.compactHeightRange), step: 1)
                    Text(verbatim: "\(Int(model.topHeight + model.compactExtraHeight)) pt").monospacedDigit().frame(width: 60)
                }
                HStack {
                    Text(model.t("Expanded island width"))
                    Slider(value: $model.panelWidth, in: 360...720, step: 2)
                    Text(verbatim: "\(Int(model.panelWidth)) pt").monospacedDigit().frame(width: 60)
                }
                Text(model.t("The compact island starts at the size of the physical notch (%1$@ × %2$@ pt here), so nothing shows beside the camera housing. Widen or heighten it to bring the artwork and the spectrum out from behind the notch; they stay on the left and right edges. Lyrics add their own height below.",
                             "\(Int(model.notchWidth))", "\(Int(model.topHeight))"))
                    .font(.caption).foregroundStyle(.secondary)
                Button(model.t("Reset to the notch size")) { model.resetIslandSize() }
                Picker(model.t("Accent color"), selection: $model.accentName) {
                    Text(model.t("Auto — from artwork")).tag("Auto")
                    Text(model.t("Peach")).tag("Peach")
                    Text(model.t("Lavender")).tag("Lavender")
                    Text(model.t("Neutral")).tag("Netral")
                }
                Toggle(model.t("Smooth panel transitions (ease-in/ease-out)"), isOn: $model.animations)
                Toggle(model.t("Show lyrics in the island"), isOn: $music.showLyrics)
                Picker(model.t("Lyric lines"), selection: $music.lyricLineCount) {
                    Text(model.t("1 · current")).tag(1)
                    Text(model.t("2 · current + next")).tag(2)
                    Text(model.t("3 · previous + current + next")).tag(3)
                }.disabled(!music.showLyrics)
                Text(model.t("Applies to compact and expanded islands. The spectrum is decorative, not audio analysis, and settles when paused or stopped. The animation toggle and Reduce Motion also control it."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
