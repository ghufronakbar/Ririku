import SwiftUI

struct PrototypePage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        Form {
            Section(model.t("Prototype")) {
                Toggle(model.t("Local demo (no audio)"), isOn: $music.demo)
                Text(model.t("Shows a sample song with synced lyrics, so you can try the panel without a browser. Turn it off before playing real music."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
