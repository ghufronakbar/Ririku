import SwiftUI
@preconcurrency import Translation
import RirikuCore

/// The Translate tab (D-019): off by default, translated on this Mac only (R-WID-10). The text is kept in memory,
/// never saved or logged (R-SEC-6). Translation starts 0.6 s after typing stops, or at once with Return.
@MainActor
final class TranslateStore: ObservableObject {
    enum State: Equatable {
        case idle, translating, done, sameLanguage, unknownLanguage, unsupported, failed
        case needsDownload(source: String)
    }

    /// Text that the panel's translation task translates next. A new job runs the task again.
    struct Job: Equatable {
        let id = UUID()
        let text: String
        let source: String
        let target: String
    }

    static let pause: Duration = .milliseconds(600)

    @Published private(set) var enabled: Bool
    /// nil detects the language of the text.
    @Published var source: String? {
        didSet { defaults.set(source, forKey: "translateSource"); requestTranslation(now: true) }
    }
    @Published var target: String {
        didSet { defaults.set(target, forKey: "translateTarget"); requestTranslation(now: true) }
    }
    @Published var input = "" { didSet { if input != oldValue { requestTranslation(now: false) } } }
    @Published private(set) var output = ""
    /// The language found in the text while the source is detected.
    @Published private(set) var detected: String?
    @Published private(set) var state: State = .idle
    @Published private(set) var job: Job?
    @Published private(set) var languages: [String] = []

    private let defaults: UserDefaults
    private var pending: Task<Void, Never>?
    /// Replaced in tests, which must not depend on the languages this Mac has downloaded.
    var languageList: () async -> [String] = { await TranslationService.languages() }
    var availabilityCheck: (String, String) async -> TranslationAvailability = { await TranslationService.availability(from: $0, to: $1) }

    init(defaults: UserDefaults, defaultTarget: String) {
        self.defaults = defaults
        enabled = TranslationService.isAvailable && defaults.bool(forKey: "translateTab")
        source = defaults.string(forKey: "translateSource")
        target = defaults.string(forKey: "translateTarget") ?? defaultTarget
    }

    func setEnabled(_ on: Bool) {
        enabled = on && TranslationService.isAvailable
        defaults.set(enabled, forKey: "translateTab")
        if !enabled { clear() }
    }

    func loadLanguages() async {
        if languages.isEmpty { languages = await languageList() }
    }

    func clear() {
        pending?.cancel()
        input = ""
        output = ""
        detected = nil
        state = .idle
        job = nil
    }

    /// Turns the pair around and continues from the translation.
    func swap() {
        guard let from = source ?? detected else { return }
        let text = output
        source = target
        target = from
        if !text.isEmpty { input = text }
    }

    /// Tries again, for example after the languages were downloaded in Setup.
    func retry() { requestTranslation(now: true) }

    /// The returned task ends once the text is ready to translate or cannot be translated.
    @discardableResult
    func requestTranslation(now: Bool) -> Task<Void, Never>? {
        pending?.cancel()
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            output = ""
            detected = nil
            state = .idle
            job = nil
            return nil
        }
        let task = Task { [weak self] in
            if !now { try? await Task.sleep(for: Self.pause) }
            guard !Task.isCancelled else { return }
            await self?.prepare(text)
        }
        pending = task
        return task
    }

    /// Finds the source language and checks that the pair is on this Mac. Languages are downloaded in Setup, so the
    /// panel never starts a download (D-027).
    private func prepare(_ text: String) async {
        await loadLanguages()
        guard !Task.isCancelled else { return }
        let from = source ?? TranslationService.detect(text, in: languages)
        detected = source == nil ? from : nil
        guard let from else { return finish(.unknownLanguage) }
        if TranslationLanguage.same(from, target) { return finish(.sameLanguage) }
        let availability = await availabilityCheck(from, target)
        guard !Task.isCancelled else { return }
        switch availability {
        case .installed:
            state = .translating
            job = Job(text: text, source: from, target: target)
        case .downloadable: finish(.needsDownload(source: from))
        case .unsupported: finish(.unsupported)
        }
    }

    private func finish(_ state: State) {
        output = ""
        job = nil
        self.state = state
    }

    @available(macOS 15, *)
    func run(_ session: TranslationSession) async {
        guard let job else { return }
        do {
            complete(job, output: try await session.translate(job.text).targetText)
        } catch {
            complete(job, output: nil)
        }
    }

    /// Shows the translation of `job`, or notes the failure when `output` is nil. A late result for earlier text is
    /// dropped.
    func complete(_ job: Job, output: String?) {
        guard self.job == job else { return }
        guard let output else { state = .failed; return }
        self.output = output
        state = .done
    }
}
