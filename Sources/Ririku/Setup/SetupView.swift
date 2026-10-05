import SwiftUI

/// Pages of the Setup window, in sidebar order.
enum SetupPage: CaseIterable, Identifiable {
    case general, tutorial, language, keyboard, appearance, browserConnection, musicSource, lyrics, prototype, about

    var id: Self { self }

    @MainActor
    func title(_ model: AppModel) -> String {
        switch self {
        case .general: return model.t("General")
        case .tutorial: return model.t("Tutorial")
        case .language: return model.t("Language")
        case .keyboard: return model.t("Keyboard")
        case .appearance: return model.t("Appearance")
        case .browserConnection: return model.t("Browser connection")
        case .musicSource: return model.t("Music source")
        case .lyrics: return model.t("Lyrics")
        case .prototype: return model.t("Prototype")
        case .about: return model.t("About")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .tutorial: return "book"
        case .language: return "globe"
        case .keyboard: return "keyboard"
        case .appearance: return "paintbrush"
        case .browserConnection: return "puzzlepiece.extension"
        case .musicSource: return "music.note"
        case .lyrics: return "text.quote"
        case .prototype: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

/// The Setup window: a sidebar with one page per area. The selected page lives in `AppModel.setupPage`,
/// so the menus can open Setup on a given page.
struct SetupView: View {
    static let minimumSize = CGSize(width: 720, height: 520)

    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    /// Kept here rather than on the Lyrics page, so a search survives switching pages.
    @State private var lyricSearchText = ""

    init(model: AppModel) {
        self.model = model
        music = model.music
    }

    var body: some View {
        NavigationSplitView {
            List(SetupPage.allCases, selection: $model.setupPage) { page in
                Label(page.title(model), systemImage: page.icon)
            }
            // A settings window always shows its pages.
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            Group {
                switch model.setupPage ?? .general {
                case .general: GeneralPage(model: model)
                case .tutorial: TutorialPage(model: model)
                case .language: LanguagePage(model: model)
                case .keyboard: KeyboardPage(model: model)
                case .appearance: AppearancePage(model: model, music: music)
                case .browserConnection: BrowserConnectionPage(model: model, music: music)
                case .musicSource: MusicSourcePage(model: model, music: music)
                case .lyrics: LyricsPage(model: model, music: music, searchText: $lyricSearchText)
                case .prototype: PrototypePage(model: model, music: music)
                case .about: AboutPage(model: model)
                }
            }
            .formStyle(.grouped)
        }
        .environment(\.locale, model.locale)
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .onAppear { resetSearch() }
        .onChange(of: music.lyricSearchIdentity) { _, _ in resetSearch() }
    }

    private func resetSearch() {
        music.cancelLyricSearch()
        lyricSearchText = music.suggestedLyricSearch
    }
}
