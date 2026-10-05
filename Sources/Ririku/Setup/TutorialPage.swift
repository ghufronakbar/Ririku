import SwiftUI

struct TutorialPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(model.t("Tutorial")) {
                step("cursorarrow.rays", model.t("Open the panel"),
                     model.t("Hover over the notch or click the island. You can also record a keyboard shortcut or choose Open music panel from the menu bar icon. Move the pointer away or press Esc to close it."),
                     page: .keyboard)
                step("puzzlepiece.extension", model.t("Connect your music"),
                     model.t("Load the browser extension for YouTube and YouTube Music, or connect the Spotify or Apple Music app."),
                     page: .browserConnection)
                step("rectangle.3.group", model.t("Arrange the panel"),
                     model.t("Choose which widgets the expanded panel shows, on which page, and whether each one is small or wide."),
                     page: .layout)
                step("text.quote", model.t("Get the right lyrics"),
                     model.t("Lyrics are found automatically. If the timing is off, adjust the offset; if the version is wrong, search for another one."),
                     page: .lyrics)
                step("paintbrush", model.t("Make it yours"),
                     model.t("Change the island's size, the lyric lines, and the accent color. The General page chooses the display, the delays, and the icons."),
                     page: .appearance)
                step("wrench.and.screwdriver", model.t("Try it without music"),
                     model.t("Turn on the local demo to see the panel with a sample song."),
                     page: .prototype)
            }
        }
    }

    private func step(_ icon: String, _ title: String, _ detail: String, page: SetupPage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(.tint).frame(width: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(page.title(model)) { model.setupPage = page }
        }
        .padding(.vertical, 4)
    }
}
