import SwiftUI
@preconcurrency import Translation
import RirikuCore

/// Display-only lyric translation (D-019, D-027): the synced lines of the current song are translated on this Mac
/// in one batch and shown under the active line in the expanded panel. They are kept in memory for the last few
/// songs and never change the lyrics or the lyrics cache (R-LYR-6, R-WID-10).
@MainActor
final class LyricTranslator: ObservableObject {
    enum Status: Equatable {
        case idle, translating, sameLanguage, unknownLanguage, failed
        case done(source: String)
        case needsDownload(source: String)
        case unsupported(source: String)
    }

    struct Result: Sendable {
        let source: String
        let lines: [String]
    }

    /// The lines of one song to translate. A new job runs the panel's translation task again.
    struct Job: Equatable {
        let key: String
        let source: String
        let target: String
        let lines: [String]
        let indices: [Int]
    }

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "lyricTranslation"); changed?() }
    }
    @Published var target: String {
        didSet { defaults.set(target, forKey: "lyricTranslationTarget"); changed?() }
    }
    @Published private(set) var status: Status = .idle
    @Published private(set) var job: Job?
    /// Called when the lines shown in the panel may change, so the panel resizes.
    var changed: (() -> Void)?
    /// Replaced in tests, which must not depend on the languages this Mac has downloaded.
    var languageList: () async -> [String] = { await TranslationService.languages() }
    var availabilityCheck: (String, String) async -> TranslationAvailability = { await TranslationService.availability(from: $0, to: $1) }

    private let defaults: UserDefaults
    private var memory = TranslationMemory<Result>()
    private var last: (key: String, lines: [String])?

    init(defaults: UserDefaults, defaultTarget: String) {
        self.defaults = defaults
        enabled = TranslationService.isAvailable && defaults.bool(forKey: "lyricTranslation")
        target = defaults.string(forKey: "lyricTranslationTarget") ?? defaultTarget
    }

    /// The translations of a song's lines, one per line, empty for lines that need none.
    func translations(for key: String) -> [String]? { memory[key]?.lines }

    /// True when the song has translations or is being translated, so the panel keeps a row for them.
    func expects(_ key: String) -> Bool { memory[key] != nil || job?.key == key }

    /// Called by the panel whenever the song, its lines, or the settings change. `key` identifies the lines and the
    /// target; a result for an earlier key is dropped (R-LYR-5).
    func prepare(key: String?, lines: [String]) async {
        guard enabled, TranslationService.isAvailable, let key, !lines.isEmpty else {
            last = nil
            update(.idle, job: nil)
            return
        }
        last = (key, lines)
        if let result = memory[key] { return update(.done(source: result.source), job: nil) }
        let languages = await languageList()
        guard last?.key == key else { return }
        guard let source = TranslationService.detect(lines.joined(separator: "\n"), in: languages) else {
            return update(.unknownLanguage, job: nil)
        }
        let target = target
        if TranslationLanguage.same(source, target) { return update(.sameLanguage, job: nil) }
        let availability = await availabilityCheck(source, target)
        guard last?.key == key else { return }
        switch availability {
        case .installed:
            // Lines already in the target language, such as English lines in a Japanese song, stay as they are.
            let indices = LyricTranslationPlan.lineIndices(lines) { TranslationService.isClearly($0, in: target) }
            update(.translating, job: Job(key: key, source: source, target: target, lines: lines, indices: indices))
        case .downloadable: update(.needsDownload(source: source), job: nil)
        case .unsupported: update(.unsupported(source: source), job: nil)
        }
    }

    /// Tries the current song again, for example after its languages were downloaded in Setup.
    func retry() {
        guard let last else { return }
        Task { await prepare(key: last.key, lines: last.lines) }
    }

    @available(macOS 15, *)
    func run(_ session: TranslationSession) async {
        guard let job else { return }
        let requests = job.indices.map { TranslationSession.Request(sourceText: job.lines[$0], clientIdentifier: String($0)) }
        do {
            let responses = requests.isEmpty ? [] : try await session.translations(from: requests)
            complete(job, responses: responses.map { ($0.clientIdentifier, $0.targetText) })
        } catch {
            complete(job, responses: nil)
        }
    }

    /// Keeps the result of `job`, or notes the failure when `responses` is nil. A result for a song that is no longer
    /// current is dropped (R-LYR-5).
    func complete(_ job: Job, responses: [(id: String?, text: String)]?) {
        guard self.job == job else { return }
        guard let responses else { return update(.failed, job: nil) }
        let lines = LyricTranslationPlan.assemble(lineCount: job.lines.count, responses: responses)
        memory.store(Result(source: job.source, lines: lines), for: job.key)
        update(.done(source: job.source), job: nil)
    }

    private func update(_ status: Status, job: Job?) {
        let rowChanged = (self.job == nil) != (job == nil) || status != self.status
        self.status = status
        self.job = job
        if rowChanged { changed?() }
    }
}

extension View {
    /// Translates the current song's lyrics while lyric translation is on. The session comes from SwiftUI, so this
    /// sits on the notch panel, which is always on screen.
    @ViewBuilder
    func lyricTranslationTask(_ music: MusicModel) -> some View {
        if #available(macOS 15, *) {
            modifier(LyricTranslationModifier(music: music, translator: music.lyricTranslator))
        } else {
            self
        }
    }
}

@available(macOS 15, *)
private struct LyricTranslationModifier: ViewModifier {
    @ObservedObject var music: MusicModel
    @ObservedObject var translator: LyricTranslator
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        let key = translator.enabled ? music.lyricTranslationKey : nil
        content
            .task(id: key) { await translator.prepare(key: key, lines: music.lyricTranslationLines) }
            .translationTask(configuration) { session in await translator.run(session) }
            .onChange(of: translator.job) { _, job in
                guard let job else { return }
                configuration = .pair(source: job.source, target: job.target, reusing: configuration)
            }
    }
}
