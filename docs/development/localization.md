# Localization

Ririku's interface is available in English, Bahasa Indonesia (`id`), and Japanese (`ja`). English is the source language. This page explains how to change interface text, translate it, and add a language.

## How it works

- **Keys are English text.** Code calls `model.t("Show in Finder")` or stores `UIText("Lyrics not found")`. If a translation is missing, the English key is shown.
- **Translations** live in `Localization/<code>.lproj/Localizable.strings`. `en.lproj` only contains a comment so macOS lists English as supported.
- **Placeholders** use `%@` for every argument (arguments are passed as strings). Use positional placeholders such as `%1$@` and `%2$@` when a translation needs a different order. Never use Swift string interpolation inside a key.
- **Runtime:** `InterfaceLanguage` stores the choice (`system`, `en`, `id`, `ja`). `Localizer` loads `<code>.lproj` from the app bundle directly, so switching language in Setup updates the UI without restarting. System mode picks the first supported language from macOS preferences, otherwise English.
- **Stored messages:** statuses and errors kept in `AppModel` are `UIText` values (key plus arguments) and are translated when displayed. `BridgeError.system("…", [arguments])` works the same way; its `errorDescription` stays English for logs.
- **Numbers:** format decimals with the interface `Locale` (`model.locale`) so Indonesian shows `0,1` and Japanese `0.1`.
- **Not translated:** song titles, artists, lyrics, captions, service names from the extension, and messages from macOS frameworks.
- **Extension:** popup and toolbar text live in `extension/i18n.js` (`RIRIKU_MESSAGES`). The popup uses the app's language when connected, then Chrome's UI language, then English. The extension name and description in `chrome://extensions` come from `extension/_locales/<code>/messages.json` and follow Chrome's language.

## Changing or adding interface text

1. Write the English text in code with `model.t`, `UIText`, or `BridgeError.system`.
2. Add the same key with a translation to `Localization/id.lproj/Localizable.strings` and `Localization/ja.lproj/Localizable.strings`. If you cannot translate, open the pull request anyway and ask for help; do not leave the English text as a fake translation.
3. Run the checker:

   ```sh
   /usr/bin/python3 scripts/check-localization.py
   ```

   It fails when a key used in `Sources/Ririku` or `Sources/RirikuCore` is missing from a language, when a translation has a different number of placeholders, or when a translation is no longer used. `build-app.sh` runs it automatically.

4. Build and look at the change in each language (**Setup → Language**). Japanese and Indonesian text is often longer or wraps differently.

Keep the `.strings` syntax valid (`"key" = "value";`, escape `"` and `\`). `plutil -lint Localization/*/Localizable.strings` reports syntax errors.

## Adding a language

1. Create `Localization/<code>.lproj/Localizable.strings` with every key (copy `id.lproj` as a template and translate the values).
2. In `Sources/Ririku/Localization.swift`, add a case to `InterfaceLanguage`, add the code to `supportedCodes`, and add its native name in `nativeName(of:)`.
3. In `Sources/Ririku/SetupView.swift`, add the language to the picker.
4. In `scripts/build-app.sh`, add the code to `CFBundleLocalizations`. In `scripts/check-localization.py`, add it to `LANGUAGES`.
5. In `extension/i18n.js`, add a message table with the same keys, and add `extension/_locales/<code>/messages.json`. The popup accepts only codes listed in `RIRIKU_MESSAGES`, and the service worker only accepts `en`, `id`, and `ja` from the app, so update that list in `background.js` too.
6. Optionally translate `README.md` and `docs/user-guide.md` as `README.<code>.md` and `docs/user-guide.<code>.md`, and link them from the language switchers at the top of the existing files.

## Translation style

- Match the names macOS and Chrome use in that language when the text refers to their buttons or settings.
- Keep technical words users will see elsewhere (Chrome, Finder, LRCLIB, LRC, CC) as they are.
- Prefer short labels for toggles and buttons; the Setup window is 580 pt wide.
- Translated documentation starts with a note naming the English version it was translated from. When you update the English user guide, update the translations or mention in the pull request that they need updating.
