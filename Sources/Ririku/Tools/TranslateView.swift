import AppKit
import SwiftUI
@preconcurrency import Translation
import RirikuCore

/// The Translate tab: the languages above, the text on the left, and its translation on the right.
struct TranslateView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var translate: TranslateStore
    @State private var copied = false

    var body: some View {
        Group {
            if TranslationService.isAvailable {
                VStack(spacing: 8) {
                    languageBar
                    HStack(spacing: 8) {
                        inputBox
                        outputBox
                    }
                }
                .translateTask(translate)
                .task { await translate.loadLanguages() }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "translate").font(.system(size: 24, weight: .medium))
                    Text(model.t("Translate needs macOS 15 or later.")).font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(box)
            }
        }
        .frame(height: ToolKind.translate.contentHeight)
    }

    private var box: some View { RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)) }

    private func name(_ code: String) -> String {
        TranslationService.name(code, among: translate.languages, locale: model.locale)
    }

    private var sortedLanguages: [String] {
        translate.languages.sorted { name($0).localizedCompare(name($1)) == .orderedAscending }
    }

    // MARK: Languages

    private var languageBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button(model.t("Detect Language")) { translate.source = nil }
                Divider()
                ForEach(sortedLanguages, id: \.self) { code in Button(name(code)) { translate.source = code } }
            } label: {
                menuLabel(translate.source.map(name) ?? translate.detected.map { model.t("Detected: %@", TranslationService.languageName($0, locale: model.locale)) } ?? model.t("Detect Language"))
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(model.t("Translate from"))
            WidgetButton(icon: "arrow.left.arrow.right", label: model.t("Swap Languages"), size: 22) { translate.swap() }
                .disabled(translate.source == nil && translate.detected == nil)
            Menu {
                ForEach(sortedLanguages, id: \.self) { code in Button(name(code)) { translate.target = code } }
            } label: { menuLabel(name(translate.target)) }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(model.t("Translate into"))
            Spacer(minLength: 0)
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.6))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10).frame(height: 22)
        .background(Capsule().fill(.white.opacity(0.1)))
        .contentShape(Capsule())
    }

    // MARK: Text

    private var inputBox: some View {
        TextField("", text: $translate.input, prompt: Text(model.t("Type or paste text")), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .lineLimit(5, reservesSpace: true)
            .onSubmit { translate.retry() }
            .padding(8)
            .padding(.trailing, translate.input.isEmpty ? 0 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(box)
            .overlay(alignment: .topTrailing) {
                if !translate.input.isEmpty {
                    WidgetButton(icon: "xmark", label: model.t("Clear"), size: 18) { translate.clear() }.padding(5)
                }
            }
            .accessibilityLabel(model.t("Text to translate"))
    }

    private var outputBox: some View {
        ZStack(alignment: .topLeading) {
            if translate.output.isEmpty {
                status.padding(8)
            } else {
                ScrollView {
                    Text(translate.output).font(.system(size: 13)).foregroundStyle(.white).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8).padding(.bottom, 20)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(box)
        .overlay(alignment: .bottomTrailing) {
            if !translate.output.isEmpty {
                WidgetButton(icon: copied ? "checkmark" : "doc.on.doc", label: model.t("Copy"), size: 22) { copy() }.padding(5)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.t("Translation"))
    }

    @ViewBuilder
    private var status: some View {
        let note = Text(statusText).font(.caption).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
        switch translate.state {
        case .translating:
            ProgressView().controlSize(.small)
        case .needsDownload:
            VStack(alignment: .leading, spacing: 6) {
                note
                Button(model.t("Open Setup")) {
                    model.setupPage = .widgets
                    model.openSetup?()
                }
                .buttonStyle(.plain).font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.14)))
            }
        default:
            note
        }
    }

    private var statusText: String {
        switch translate.state {
        case .idle, .done, .translating: return model.t("The translation appears here.")
        case .sameLanguage: return model.t("The text is already in %@.", TranslationService.languageName(translate.target, locale: model.locale))
        case .unknownLanguage: return model.t("The language of the text was not recognized. Choose it above.")
        case .unsupported: return model.t("These languages cannot be translated into each other.")
        case .failed: return model.t("The translation failed. Press Return to try again.")
        case .needsDownload(let source):
            return model.t("Download %@ and %@ in Setup → Widgets to translate on this Mac.", name(source), name(translate.target))
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translate.output, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

extension View {
    /// Runs the panel's translations. The session comes from SwiftUI, so it lives with the Translate tab.
    @ViewBuilder
    func translateTask(_ store: TranslateStore) -> some View {
        if #available(macOS 15, *) {
            modifier(TranslateTaskModifier(store: store))
        } else {
            self
        }
    }
}

@available(macOS 15, *)
private struct TranslateTaskModifier: ViewModifier {
    @ObservedObject var store: TranslateStore
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in await store.run(session) }
            .onChange(of: store.job, initial: true) { _, job in
                guard let job else { return }
                configuration = .pair(source: job.source, target: job.target, reusing: configuration)
            }
    }
}
