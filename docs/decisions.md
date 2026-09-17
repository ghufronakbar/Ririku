# Decision log

This log records product decisions and notable technical choices. It replaces the Indonesian [05-decisions.md](archive/id/05-decisions.md), which keeps the full history up to v0.3.0.

- **Decisions** (D-numbers) were agreed by the project owner.
- **Technical choices** were made while implementing and can be revisited in an issue or pull request.
- An implemented feature is not automatically an agreed decision, and a mockup or proposal is not an implemented feature.

When a decision changes, add a dated entry here, update the affected documents, and explain why.

## Decisions

| ID | Decision | Date and reason |
| --- | --- | --- |
| D-001 | Ririku is a simple, native macOS app. | 2026-09-17. Personal use first; no complex utility suite. |
| D-002 | Focus on music controls, synced lyrics, and a polished notch UI with smooth animation. | 2026-09-17. Core need. Out of scope: word-by-word karaoke, audio downloads, DRM bypass, file shelf, clipboard, calendar, weather, cloud accounts. |
| D-003 | Target players: YouTube and YouTube Music in Chrome, Apple Music, and Spotify desktop apps. | 2026-09-17. Requested player coverage; desktop adapters still need validation. |
| D-004 | Chrome is the first priority. | 2026-09-17. The owner's daily player. |
| D-005 | A companion Chrome extension is allowed. | 2026-09-17. Needed to read and control the web player. |
| D-006 | Documentation came before mockups and implementation. | 2026-09-17. Planning phase. |
| D-007 | Visual settings are adjustable in a separate Setup window. | 2026-09-17. Owner direction. |
| D-008 | The source picker lives in Setup, not in the notch panel. | 2026-09-17. Keeps the panel focused on music and lyrics. |
| D-009 | Move from mockup review to a native prototype. | 2026-09-17. Not an approval of every later technical detail. |
| D-010 | Automatic lyrics, real artwork, automatic source selection and recovery, and an extension popup with status. LRC import is a fallback. | 2026-09-17. After first user testing. |
| D-011 | Interface in English, Bahasa Indonesia, and 日本語; follow the system language with English fallback, plus a live language picker in Setup. | 2026-09-17. Chosen after a feasibility study. |
| D-012 | Open source under the name **Ririku**, MIT license, maintained by `lanstheprodigy` at `github.com/ghufronakbar/ririku`. | 2026-09-17. "Notch Box" collided with the NotchBox app on the Mac App Store; "Ririkku" collided with a lyrics music player at ririkku.com. No music or lyrics app named Ririku was found in web searches (not a formal trademark search). MIT is simple and there are no third-party dependencies. |
| D-013 | Free distribution: ad-hoc signed GitHub releases without notarization, extension installed with Load unpacked and a tutorial, no migration of Notch Box settings. | 2026-09-17. The owner does not want paid programs (Apple Developer Program, Chrome Web Store). |
| D-014 | English is the primary documentation language; user-facing documentation is also available in other languages. | 2026-09-17. Open-source audience. |

Earlier approved requirements recorded in the archive include: selectable lyrics source with per-song offset and duration-based version picking (v0.2.2); lyric visibility, 1/2/3 lines, adjustable width, and smoother transitions (v0.2.3); top-anchored resizing, no auto-expand on track change, short "not found" notice, decorative spectrum, and Japanese line preference (v0.2.4).

## Technical choices

| Area | Choice | Notes |
| --- | --- | --- |
| Stack | Swift Package Manager, SwiftUI + AppKit, macOS 14+ | Builds with the Command Line Tools only. |
| Browser bridge | Chrome native messaging host + Unix domain socket with peer UID checks | No network listener. One Chrome profile at a time. |
| Lyrics provider | LRCLIB with conservative automatic matching (title, artist, ±3 s) and a local cache | Duration is used for matching, never to stretch timestamps. Content licensing for lyrics needs review before any bundled distribution. |
| Playback clock | Latest snapshot plus monotonic interpolation, capped at 5 s | Heartbeat every second; sessions stale after 5 s. |
| Spectrum | Decorative animation, no audio capture | Real audio analysis would need Screen Recording or tab capture permissions. |
| Japanese lines | Display-only filter for Latin lines sharing a timestamp with Japanese | Raw lyrics and cache unchanged; can be turned off. |
| Localization | `.strings` with English keys, `.lproj` copied by the build script, live lookup through `.lproj` sub-bundles | String Catalogs need Xcode; SwiftPM `Bundle.module` breaks inside the signed app. |
| Identifiers | `io.github.lanstheprodigy.ririku` and related names, version 0.3.0 | Changed from `local.notchbox.*` without migration. Kept unchanged when the repository moved to the `ghufronakbar` account (2026-09-18), so installations do not need to re-register Chrome again; only links were updated. |
| Chrome setup | Fixed extension ID through the manifest `key`; the app registers the native host and copies the extension only when the user clicks Setup buttons; blocked under App Translocation | Setup copies `chrome://extensions` to the clipboard instead of opening it, because opening Chrome internal pages from an app is unvalidated. `install-host.py` remains for development. |
| Documentation | English README, user guide, and developer docs; Indonesian and Japanese README and user guide; original Indonesian planning docs archived; community files added | Translations name the English version they follow. |
| CI and releases | GitHub Actions on macOS runners: checks, `swift test`, and a bundle build on every push, plus tag-driven draft releases with a zip and checksum | Uses only first-party actions (`actions/checkout`, `actions/upload-artifact`) and `gh`. |
| Tests | Swift Testing suites in `Tests/RirikuCoreTests` and `Tests/RirikuTests`, fixtures only | Executable targets can be tested with SwiftPM, so the app model and Chrome setup are covered without a UI. |

## Open questions

| Question | Status |
| --- | --- |
| Apple Music and Spotify desktop integration (scripting capabilities, permissions) | Open |
| Behavior on external displays, full screen, Spaces, and Macs without a notch | Open; main-screen fallback not fully tested |
| Gatekeeper experience for downloaded ad-hoc builds on each macOS version, and whether updates require confirming again | Needs validation with a real release |
| Universal (Intel) builds | Open |
| GitHub repository settings (issues, labels, private vulnerability reporting) and whether a separate code of conduct with a contact address is needed | Open; basic conduct expectations are in CONTRIBUTING.md |
| Test coverage for SwiftUI views, the Chrome extension JavaScript, and end-to-end bridge behavior | Open; `swift test` now covers core logic, the app model, localization, and Chrome setup helpers |
| Launch at login and other Chromium browsers | Planned, not started |
