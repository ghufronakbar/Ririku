import SwiftUI

/// Pages of the Setup window, in sidebar order. A title is the English key of the page's section header.
enum SetupPage: CaseIterable, Identifiable {
    case language, browserConnection, startup, musicSource, appearance, lyrics, prototype

    var id: Self { self }

    var title: String {
        switch self {
        case .language: return "Language"
        case .browserConnection: return "Browser connection"
        case .startup: return "Startup"
        case .musicSource: return "Music source"
        case .appearance: return "Appearance"
        case .lyrics: return "Lyrics"
        case .prototype: return "Prototype"
        }
    }

    var icon: String {
        switch self {
        case .language: return "globe"
        case .browserConnection: return "puzzlepiece.extension"
        case .startup: return "power"
        case .musicSource: return "music.note"
        case .appearance: return "paintbrush"
        case .lyrics: return "text.quote"
        case .prototype: return "wrench.and.screwdriver"
        }
    }
}

/// The Setup window: a sidebar with one page per area.
struct SetupView: View {
    static let minimumSize = CGSize(width: 720, height: 520)

    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    @State private var page: SetupPage?
    /// Kept here rather than on the Lyrics page, so a search survives switching pages.
    @State private var lyricSearchText = ""

    init(model: AppModel) {
        self.model = model
        music = model.music
        // Until a browser has connected, Setup opens where the connection is made.
        _page = State(initialValue: model.music.connectedExtensionVersion == nil ? .browserConnection : .language)
    }

    var body: some View {
        NavigationSplitView {
            List(SetupPage.allCases, selection: $page) { page in
                Label(model.t(page.title), systemImage: page.icon)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            Group {
                switch page ?? .language {
                case .language: LanguagePage(model: model)
                case .browserConnection: BrowserConnectionPage(model: model, music: music)
                case .startup: StartupPage(model: model)
                case .musicSource: MusicSourcePage(model: model, music: music)
                case .appearance: AppearancePage(model: model, music: music)
                case .lyrics: LyricsPage(model: model, music: music, searchText: $lyricSearchText)
                case .prototype: PrototypePage(model: model, music: music)
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
