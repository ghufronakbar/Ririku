# Agent guide

This guide applies to the whole repository through the `AGENTS.md` symlink at the root (`CLAUDE.md` includes it). Edit the source in `docs/AGENTS.md` and keep the symlink relative.

## Rules come first

`docs/rules.md` is binding. Read it before every change and follow it over any habit or default of your own:

- If a request conflicts with a rule, do not work around it. Stop, name the rule ID, and ask the project owner.
- Only the project owner can change a rule. When they do, update `docs/rules.md`, add a dated entry with the reason to `docs/decisions.md`, and update the affected documents in the same change.
- Cite the rule IDs a change touches in the commit body or pull request when it is not obvious.

## Required context

Read `README.md`, `docs/rules.md`, and the documents relevant to the change (paths relative to the repository root):

- `docs/user-guide.md`: user-facing behavior, settings, installation, and privacy.
- `docs/development/README.md`: layout, build, browser setup for development, and verification.
- `docs/development/architecture.md`: components, bridge protocol, clock, lyrics pipeline, UI, and security boundaries.
- `docs/development/localization.md`: interface text and translations.
- `docs/development/releasing.md`: versioning and releases.
- `docs/decisions.md`: agreed decisions, technical choices, and open questions.
- `CONTRIBUTING.md`: pull request and commit conventions.

The planning history before v0.3.0 is in Git history, not in the working tree. Do not restore or cite it as a current requirement; its rules that still apply are in `docs/rules.md`.

## Working method

- Ask before hard-to-reverse or outward-facing actions: pushing, tagging, publishing a release, or changing repository settings.
- Match the surrounding code: naming, comment density, and structure. Keep changes focused on the request.
- For interface text, write English in code and update `Localization/id.lproj` and `Localization/ja.lproj` (R-DOC-1).
- Record changes in `CHANGELOG.md` under the unreleased version (R-DOC-4), and update the user guide and its translations when behavior changes (R-DOC-3).

## Validation

- Run the verification commands in `docs/development/README.md` that apply to the change, including `swift test`, and the manual smoke test when behavior with a browser or desktop player changes. `scripts/check-localization.py`, `scripts/check-version.py`, and `scripts/check-docs.py` also run in CI.
- Report what was run and its limits, following R-HONEST: never claim a build, test, integration, or performance result without evidence, and name the manual checks that were not done.
- For documentation changes, check consistency between documents, that claims match the code, and that relative links work.
