# Agent guide

This guide applies to the whole repository through the `AGENTS.md` symlink at the root. Edit the source in `docs/AGENTS.md` and keep the symlink relative.

## Required context

Before changing the project, read `README.md` and the documents relevant to the change (paths relative to the repository root):

- `docs/user-guide.md`: user-facing behavior, settings, installation, and privacy.
- `docs/development/README.md`: layout, build, Chrome setup for development, and verification.
- `docs/development/architecture.md`: components, bridge protocol, clock, lyrics pipeline, UI, and security boundaries.
- `docs/development/localization.md`: interface text and translations.
- `docs/development/releasing.md`: versioning and releases.
- `docs/decisions.md`: agreed decisions, technical choices, and open questions.
- `CONTRIBUTING.md`: scope, pull request, and commit conventions.

`docs/archive/id/` holds the original Indonesian planning documents. Use them only for history; do not update them.

## Working rules

- Distinguish agreed decisions, technical choices, proposals, and things that still need validation. Do not treat a design, mockup, or proposal as implemented, or an implementation as an agreed decision.
- Keep the app native (Swift, SwiftUI, AppKit); do not replace the main UI with Electron or a WebView.
- Prioritize YouTube and YouTube Music in Chrome before Apple Music and Spotify desktop adapters.
- Keep the notch panel focused on music and lyrics. Source selection and visual settings belong in the separate Setup window.
- Avoid out-of-scope features, new dependencies, paid distribution requirements, and unnecessary permissions or data access (see `CONTRIBUTING.md`).
- Do not change the bundle identifier, native host name, extension `key`, or socket and cache paths without an explicit decision and migration notes.
- Write interface text in English in code and keep `Localization/id.lproj` and `Localization/ja.lproj` complete (`scripts/check-localization.py`).
- Documentation and commit messages are written in English; commit subjects use `type (area): short description`. When user-facing behavior changes, update `docs/user-guide.md`, and update `docs/user-guide.id.md`, `docs/user-guide.ja.md`, and the translated READMEs, or state clearly that they still need updating. Record changes in `CHANGELOG.md` instead of adding per-version notes to other documents.
- When a decision changes, update the affected documents and add a dated entry with the reason to `docs/decisions.md`.

## Validation

- Run the verification commands in `docs/development/README.md` that apply to the change, including `swift test`, and the manual smoke test when behavior with Chrome changes. `scripts/check-localization.py`, `scripts/check-version.py`, and `scripts/check-docs.py` also run in CI.
- Do not claim that a build, test, integration, or performance result succeeded without evidence. Report what was run and its limits. `swift test` covers core logic, the app model, localization, and Chrome setup helpers with fixtures only; UI rendering, real Chrome behavior, and audio timing still need manual checks.
- For documentation changes, check consistency between documents, that claims match the code, and that relative links work.
