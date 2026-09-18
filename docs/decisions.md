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
| D-012 | Open source under the name **Ririku**, MIT license, maintained by `lanstheprodigy` at `github.com/ghufronakbar/Ririku`. | 2026-09-17. "Notch Box" collided with the NotchBox app on the Mac App Store; "Ririkku" collided with a lyrics music player at ririkku.com. No music or lyrics app named Ririku was found in web searches (not a formal trademark search). MIT is simple and there are no third-party dependencies. |
| D-013 | Free distribution: ad-hoc signed GitHub releases without notarization, extension installed with Load unpacked and a tutorial, no migration of Notch Box settings. | 2026-09-17. The owner does not want paid programs (Apple Developer Program, Chrome Web Store). |
| D-014 | English is the primary documentation language; user-facing documentation is also available in other languages. | 2026-09-17. Open-source audience. |
| D-015 | Ririku can open itself at login, as an option that is off by default. | 2026-09-18. Owner request after the open-source preparation. Implemented with `SMAppService`; macOS keeps the state and can ask the user for approval. |
| D-016 | Support the other Chromium browsers (Brave, Edge, Vivaldi, Opera, Chromium, Arc) with the same extension, one connected browser at a time. | 2026-09-18. Owner request. Only the host manifest folder and the extensions address differ per browser, so the cost is small; simultaneous browsers would need per-connection routing in the bridge and was deliberately left out. |

Earlier approved requirements recorded in the archive include: selectable lyrics source with per-song offset and duration-based version picking (v0.2.2); lyric visibility, 1/2/3 lines, adjustable width, and smoother transitions (v0.2.3); top-anchored resizing, no auto-expand on track change, short "not found" notice, decorative spectrum, and Japanese line preference (v0.2.4).

## Technical choices

| Area | Choice | Notes |
| --- | --- | --- |
| Stack | Swift Package Manager, SwiftUI + AppKit, macOS 14+ | Builds with the Command Line Tools only. |
| Browser bridge | Chromium native messaging host + Unix domain socket with peer UID checks | No network listener. One browser profile at a time. |
| Lyrics provider | LRCLIB with conservative automatic matching (title, artist, ±3 s) and a local cache | Duration is used for matching, never to stretch timestamps. Content licensing for lyrics needs review before any bundled distribution. |
| Playback clock | Latest snapshot plus monotonic interpolation, capped at 5 s | Heartbeat every second; sessions stale after 5 s. |
| Spectrum | Decorative animation, no audio capture | Real audio analysis would need Screen Recording or tab capture permissions. |
| Japanese lines | Display-only filter for Latin lines sharing a timestamp with Japanese | Raw lyrics and cache unchanged; can be turned off. |
| Localization | `.strings` with English keys, `.lproj` copied by the build script, live lookup through `.lproj` sub-bundles | String Catalogs need Xcode; SwiftPM `Bundle.module` breaks inside the signed app. |
| Identifiers | `io.github.lanstheprodigy.ririku` and related names, version 0.3.0 | Changed from `local.notchbox.*` without migration. Kept unchanged when the repository moved to the `ghufronakbar` account (2026-09-18), so installations do not need to re-register Chrome again; only links were updated. |
| Browser setup | Fixed extension ID through the manifest `key`, which every Chromium browser derives the same way; Setup registers the host for each installed browser (found by bundle identifier) and `RirikuHost` names its browser from its parent process; the app registers the native host and copies the extension only when the user clicks Setup buttons; blocked under App Translocation. Confirmed working in Chrome on 2026-09-18: all four Setup steps completed and the app reported extension 0.3.0 | Setup copies the extensions address to the clipboard instead of opening it, because opening a browser's internal pages from an app is unvalidated. `install-host.py --browser` remains for development. |
| Documentation | English README, user guide, and developer docs; Indonesian and Japanese README and user guide; original Indonesian planning docs archived; community files added | Translations name the English version they follow. |
| CI and releases | GitHub Actions on macOS runners: checks, `swift test`, and a bundle build on every push, plus tag-driven draft releases with a zip and checksum | Uses only first-party actions (`actions/checkout`, `actions/upload-artifact`) and `gh`. |
| Launch at login | `SMAppService.mainApp` registers the app bundle itself; the state is read from macOS instead of being stored in the preferences; unavailable outside the `.app` and while translocated | No helper tool or launch agent. Registration by an ad-hoc signed build still needs validation on a downloaded release. |
| Tests | Swift Testing suites in `Tests/RirikuCoreTests` and `Tests/RirikuTests`, fixtures only | Executable targets can be tested with SwiftPM, so the app model and the browser setup are covered without a UI. |

## Open questions

| Question | Status |
| --- | --- |
| Spotify desktop and Apple Music Automation approval, playback timing, and controls | Implemented with AppleScript; real playback validation pending |
| Behavior on external displays, full screen, Spaces, and Macs without a notch | Open; main-screen fallback not fully tested |
| Gatekeeper experience for downloaded ad-hoc builds on each macOS version, and whether updates require confirming again | Needs validation with a real release |
| Universal (Intel) builds | Open |
| GitHub repository settings (issues, labels, private vulnerability reporting) and whether a separate code of conduct with a contact address is needed | Open; basic conduct expectations are in CONTRIBUTING.md |
| Test coverage for SwiftUI views, the browser extension JavaScript, and end-to-end bridge behavior | Open; `swift test` now covers core logic, the app model, localization, and the browser setup helpers |
| Whether Brave, Edge, Vivaldi, Opera, Chromium, and Arc really accept the shared extension ID and native host | Needs validation on a real install; Arc's `NativeMessagingHosts` folder is unconfirmed |
| Two browsers connected at the same time | Open; the bridge accepts one host connection, which would need per-connection command routing and `sourceId` prefixes |
| Launch at login registered by an ad-hoc signed, non-notarized build | Needs validation, including the approval prompt in System Settings |

### Spotify desktop connection — 2026-09-18

Use Spotify's local scripting interface for the requested desktop integration, without a Web API account, OAuth flow, or browser extension. Connection is opt-in and requires macOS Automation permission. Reuse the existing source-selection and LRCLIB pipeline. Limit this first adapter to standard music track URIs; ads, local files, and podcasts are not supported as songs. This adds `i.scdn.co` solely for Spotify artwork and no audio capture.

### Apple Music desktop connection — 2026-09-18

Connect the Music app through its local scripting interface, sharing one AppleScript adapter with Spotify: opt-in, macOS Automation permission, no MusicKit developer token or account. Tracks are identified by their persistent ID and commands recheck it. Artwork is read from the track's embedded data instead of an image server, so no new network host is added. Radio stations and streams without a duration are not treated as songs.

Lyrics stay on LRCLIB. Synced lyrics in Spotify and Apple Music are only reachable through private endpoints that need the user's account token, so they are not used. As a local fallback, the Music app's plain `lyrics` track property is shown when LRCLIB has nothing (2026-09-18).
