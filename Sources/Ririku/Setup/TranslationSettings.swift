import SwiftUI
import RirikuCore

/// Setup → Widgets → Translate: the tab, the language to translate into, and the languages on this Mac. Languages
/// are downloaded here, in a normal window, where the system's download prompt shows reliably (D-027).
struct TranslateSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var translate: TranslateStore
    @State private var availability: [String: TranslationAvailability] = [:]
    @State private var download: TranslationDownload?
    @State private var revision = 0

    var body: some View {
        Group {
            // The tasks sit on one row: modifiers on the group would apply to every row of the form.
            Toggle(model.t("Show the Translate tab"), isOn: Binding(get: { translate.enabled }, set: { model.setTranslateTab($0) }))
                .disabled(!TranslationService.isAvailable)
                .task { await translate.loadLanguages() }
                .task(id: "\(translate.target)|\(revision)|\(translate.languages.count)") { await loadAvailability() }
                .translationDownload(download) {
                    revision += 1
                    translate.retry()
                    model.music.lyricTranslator.retry()
                }
            if TranslationService.isAvailable {
                TranslationLanguagePicker(model: model, title: model.t("Translate into"), languages: translate.languages, selection: $translate.target)
                DisclosureGroup(model.t("Languages on this Mac")) {
                    ForEach(sortedLanguages.filter { $0 != translate.target }, id: \.self) { code in
                        LabeledContent(name(code)) { state(code) }
                    }
                }
                Text(model.t("Translation runs on this Mac with Apple's Translation framework, and text is never sent to a translation service. macOS downloads each language once; you can remove them in System Settings → General → Language & Region."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(model.t("Open Language & Region Settings")) { TranslationService.openLanguageSettings() }
            } else {
                Text(model.t("Translate needs macOS 15 or later.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func name(_ code: String) -> String { TranslationService.name(code, among: translate.languages, locale: model.locale) }

    private var sortedLanguages: [String] {
        translate.languages.sorted { name($0).localizedCompare(name($1)) == .orderedAscending }
    }

    @ViewBuilder
    private func state(_ code: String) -> some View {
        switch availability[code] {
        case .installed: Text(model.t("Downloaded")).foregroundStyle(.secondary)
        case .downloadable: Button(model.t("Download")) { download = TranslationDownload(source: code, target: translate.target) }
        case .unsupported: Text(model.t("Not available")).foregroundStyle(.secondary)
        case nil: ProgressView().controlSize(.small)
        }
    }

    private func loadAvailability() async {
        var result: [String: TranslationAvailability] = [:]
        for code in translate.languages where code != translate.target {
            result[code] = await TranslationService.availability(from: code, to: translate.target)
        }
        availability = result
    }
}

/// Setup → Lyrics → Lyric translation: on or off, the language, and how the current song is doing.
struct LyricTranslationSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var translator: LyricTranslator
    @State private var languages: [String] = []
    @State private var download: TranslationDownload?

    var body: some View {
        Group {
            // The tasks sit on one row: modifiers on the group would apply to every row of the form.
            Toggle(model.t("Translate lyrics"), isOn: $translator.enabled).disabled(!TranslationService.isAvailable)
                .task { languages = await TranslationService.languages() }
                .translationDownload(download) { translator.retry() }
            if TranslationService.isAvailable {
                TranslationLanguagePicker(model: model, title: model.t("Translate into"), languages: languages, selection: $translator.target)
                if translator.enabled, let status = statusText {
                    HStack {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                        if case .needsDownload(let source) = translator.status {
                            Spacer()
                            Button(model.t("Download")) { download = TranslationDownload(source: source, target: translator.target) }
                        }
                    }
                }
                Text(model.t("Each synced line's translation appears under it in the expanded panel. Lyrics are translated on this Mac, kept in memory only, and never changed."))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(model.t("Lyric translation needs macOS 15 or later.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func name(_ code: String) -> String { TranslationService.name(code, among: languages, locale: model.locale) }

    private var statusText: String? {
        switch translator.status {
        case .idle: return model.t("Waiting for a song with synced lyrics.")
        case .translating: return model.t("Translating the current song…")
        case .done(let source): return model.t("The current song is translated from %@.", TranslationService.languageName(source, locale: model.locale))
        case .sameLanguage: return model.t("The current song is already in %@.", TranslationService.languageName(translator.target, locale: model.locale))
        case .unknownLanguage: return model.t("The language of the current song was not recognized.")
        case .needsDownload(let source): return model.t("Download %@ to translate the current song.", name(source))
        case .unsupported(let source): return model.t("%@ cannot be translated into %@.", name(source), name(translator.target))
        case .failed: return model.t("The current song could not be translated.")
        }
    }
}

/// A picker of the languages translation offers, named in the interface language.
struct TranslationLanguagePicker: View {
    @ObservedObject var model: AppModel
    let title: String
    let languages: [String]
    @Binding var selection: String

    var body: some View {
        let names = Dictionary(uniqueKeysWithValues: languages.map { ($0, TranslationService.name($0, among: languages, locale: model.locale)) })
        let sorted = languages.sorted { (names[$0] ?? $0).localizedCompare(names[$1] ?? $1) == .orderedAscending }
        Picker(title, selection: $selection) {
            ForEach(sorted, id: \.self) { code in Text(names[code] ?? code).tag(code) }
            // A stored language that this Mac no longer offers stays selectable instead of leaving the picker empty.
            if !languages.contains(selection) {
                Text(TranslationService.name(selection, among: languages, locale: model.locale)).tag(selection)
            }
        }
    }
}
