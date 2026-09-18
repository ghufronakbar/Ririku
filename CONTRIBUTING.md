# Contributing to Ririku

Thank you for helping! Ririku is a small project maintained in spare time, so clear, focused contributions are the easiest to review. Issues and pull requests can be written in English, Bahasa Indonesia, or Japanese; English reaches the most people.

## Ways to help

- **Report a bug:** [open an issue](https://github.com/ghufronakbar/Ririku/issues) with your macOS version, Mac model (Apple silicon or Intel), browser and its version, Ririku and extension versions (shown in Setup), whether you use YouTube or YouTube Music, the steps to reproduce, and what you expected. For lyrics problems, include the song title and artist and whether **Setup → Lyrics** found a version.
- **Suggest a feature:** open an issue first so we can agree on scope before you write code.
- **Translate:** improve Bahasa Indonesia or Japanese text, or add a language. See [localization](docs/development/localization.md).
- **Improve documentation:** fix unclear steps in the [user guide](docs/user-guide.md), especially from a non-technical point of view.
- **Write code:** fix bugs or pick an issue labeled `good first issue` or `help wanted`. Tests for existing behavior are welcome too.

Security vulnerabilities must not be reported in public issues; follow [SECURITY.md](SECURITY.md).

## Project scope

Ririku focuses on music controls and synced lyrics in a native notch panel. The binding rules are in [docs/rules.md](docs/rules.md); please read them before writing code. In short:

- **Native macOS:** Swift, SwiftUI, and AppKit. The main UI must not move to Electron or a WebView.
- **Focused panel:** the notch panel is for music and lyrics. Source selection and visual customization belong in the Setup window.
- **Player priority:** YouTube and YouTube Music in Chromium browsers come first (Chrome before the others), then Apple Music and Spotify desktop apps.
- **Out of scope:** word-by-word karaoke, downloading audio or video, bypassing DRM or premium features, and general utilities such as file shelves, clipboard, calendar, or weather.
- **Privacy:** no telemetry, and no new permissions, network destinations, or data access without a clear need explained in the pull request.
- **No new dependencies** without discussing them in an issue first.
- **Free distribution:** changes must not require paid services to build or install.

## Development setup

Follow the [developer documentation](docs/development/README.md) to build the app, connect a browser, and run the verification commands. Read [architecture.md](docs/development/architecture.md) before changing the bridge, playback clock, or lyrics pipeline.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request focused on one change. Match the style of the surrounding code: naming, comment density, and structure.
3. For interface text, write English in code and update the translations (see [localization](docs/development/localization.md)).
4. If behavior, installation, or settings change, update the user guide (and its translations when you can) and `CHANGELOG.md` under the unreleased version. If a product decision changes, add an entry to [docs/decisions.md](docs/decisions.md).
5. Run the checks in the [developer documentation](docs/development/README.md#verification) that apply to your change. GitHub Actions runs them again on your pull request.
6. In the pull request, describe what changed and why, which rules in [docs/rules.md](docs/rules.md) it touches, what you tested (commands and manual steps), and what you could not test. Add screenshots for visible UI changes. Do not claim something works if you did not run it.

Write commit messages in English, in the style `type (area): short description`, for example `fix (lyrics): ignore results for a previous track` or `docs (guide): clarify Chrome setup`. Common types are `feat`, `fix`, `docs`, `test`, `refactor`, and `chore`; areas include `native`, `extension`, `lyrics`, `bridge`, `i18n`, `guide`, and `spec`.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).

## Behavior

Be respectful and constructive. Assume good intent, keep discussions about the work, and remember that contributors and users have different backgrounds and languages. Harassment and personal attacks are not tolerated; the maintainer may remove such content and block participants. To report behavior privately, contact the maintainer on X ([@lansProdigy](https://x.com/lansProdigy)) or Instagram ([@lanstheprodigy](https://instagram.com/lanstheprodigy)).
