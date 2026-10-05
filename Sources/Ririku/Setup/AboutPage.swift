import AppKit
import SwiftUI

struct AboutPage: View {
    @ObservedObject var model: AppModel

    private static let repository = "https://github.com/ghufronakbar/Ririku"

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Ririku").font(.title2.bold())
                        Text(verbatim: "Ririku 0.3.1 · Native macOS").font(.caption).foregroundStyle(.secondary)
                        Text(model.t("Synced lyrics and music controls in your Mac's notch.")).font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }
            Section(model.t("Privacy")) {
                Text(model.t("No telemetry or cookies. Song metadata is sent to LRCLIB when automatic search is on; the Search button sends your search terms. Subtitles-only mode does not query LRCLIB. Thumbnails come from YouTube/Google or Spotify image servers."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("Links")) {
                link(model.t("Source code on GitHub"), Self.repository)
                link(model.t("User guide"), Self.repository + "/blob/main/docs/" + guideFile)
                link(model.t("Report an issue"), Self.repository + "/issues")
                Text(model.t("Free and open source under the MIT License, made by lanstheprodigy. Ririku is not affiliated with Apple, Google, YouTube, or LRCLIB."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// The user guide in the interface language, which the English guide is translated into.
    private var guideFile: String {
        model.localizer.code == "en" ? "user-guide.md" : "user-guide.\(model.localizer.code).md"
    }

    private func link(_ title: String, _ address: String) -> some View {
        Link(destination: URL(string: address)!) { Label(title, systemImage: "arrow.up.right.square") }
    }
}
