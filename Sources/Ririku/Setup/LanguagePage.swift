import SwiftUI

struct LanguagePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(model.t("Language")) {
                Picker(model.t("Interface language"), selection: $model.interfaceLanguage) {
                    Text(model.t("Follow system (%@)", InterfaceLanguage.nativeName(of: InterfaceLanguage.system.resolvedCode))).tag(InterfaceLanguage.system)
                    ForEach([InterfaceLanguage.en, .id, .ja]) { language in
                        Text(InterfaceLanguage.nativeName(of: language.rawValue)).tag(language)
                    }
                }
                Text(model.t("Changes apply immediately. Song titles, lyrics, captions, and messages from macOS or websites keep their original language."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
