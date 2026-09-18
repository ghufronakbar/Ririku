# Project rules

These are the binding rules for everyone who changes Ririku: maintainers, contributors, and AI agents. They collect the requirements the project owner agreed on (see the [decision log](decisions.md)) and the engineering rules that keep the app honest, private, and predictable. The [architecture](development/architecture.md) describes *how* the current code meets them; this document says *what must stay true*.

**MUST** and **MUST NOT** are absolute. **SHOULD** means follow it unless a reason is stated in the pull request.

## How to apply these rules

- Read this document before changing the project. Cite the rule ID (for example `R-UI-3`) in a pull request or review when a change touches it.
- If a request conflicts with a rule, do not implement it silently. Stop, name the rule, and ask the project owner.
- A rule changes only by a decision of the project owner: update this document, add a dated entry with the reason to [decisions.md](decisions.md), and update the affected documents in the same change.
- A mockup, proposal, or experiment is not an implemented feature, and an implemented feature is not an agreed decision. State which one you are describing.

## Scope (R-SCOPE)

1. The app MUST stay native: Swift, SwiftUI, and AppKit. The main UI MUST NOT move to Electron, a WebView, or a web page. (D-001)
2. Ririku is about music controls, synced lyrics, and the notch panel. It MUST NOT grow word-by-word karaoke, audio or video downloads, DRM or premium-feature bypasses, or general utilities such as a file shelf, clipboard, calendar, or weather. (D-002)
3. It MUST NOT need an account, a cloud service of its own, a subscription, or a paywall. (D-001, D-013)
4. Player priority: YouTube and YouTube Music in Chromium browsers (Chrome first), then the Spotify and Apple Music desktop apps. (D-003, D-004)
5. Building and installing MUST NOT require paid programs (Apple Developer Program, notarization, Chrome Web Store). Releases are ad-hoc signed GitHub releases; the extension is installed with Load unpacked. (D-013)
6. New third-party dependencies MUST be discussed in an issue first. The project currently has none.

## Notch panel and Setup (R-UI)

1. The notch panel shows music and lyrics only. Source selection and visual settings MUST live in the separate Setup window, never in the panel or the extension popup. The panel may show the source as a read-only label. (D-007, D-008)
2. The panel MUST NOT take keyboard focus when it opens by hover. Clicking a control may make it key, but it MUST give focus back when it closes. Escape closes it.
3. The panel MUST NOT expand by itself, including when the track changes. It opens only by hover, click, or the menu bar item. (v0.2.4 requirement)
4. When the panel resizes, the top edge MUST stay fixed; only the sides and the bottom move. No scale transforms or overshoot.
5. The hardware notch is an obstructed area: no important text or control may sit under it. Sizes MUST come from the measured screen geometry, never from a hard-coded notch size, and MUST NOT exceed the screen width.
6. Loading, error, and not-found states MUST NOT stay as permanent text in the island. Details belong in Setup. A "Lyrics not found" notice may appear for about 3 seconds, at most once per track per session, and not for network failures.
7. Playback state and panel state are separate: pausing does not open or close the panel.
8. Long lyric lines MUST NOT scroll as a continuous marquee in the compact island.
9. A control the current source does not support MUST be disabled, never faked (for example, previous MUST NOT become "seek back a few seconds").
10. When a source disconnects or goes stale (5 seconds without a snapshot), the UI MUST NOT keep showing its playback as live.
11. Animations MUST respect both the app's animation setting and the system Reduce Motion setting; Reduce Motion always wins.
12. The spectrum is decorative. It MUST be labelled as not being audio analysis and MUST settle when playback is paused, stopped, buffering, or an ad. Real audio capture needs a separate decision (it would require Screen Recording or tab capture permissions).
13. Setup is one reusable window, opened only by an explicit action. Closing it MUST NOT stop playback or quit the app.
14. The extension popup shows status, reconnect, and an **Open app Setup** button. It MUST NOT relaunch the app on its own after the user quit it; the app starts only from that explicit click.
15. Accessibility: hover MUST NOT be the only way to open the panel; controls need VoiceOver labels; status MUST NOT rely on color alone; the position MUST NOT be announced on every tick.

## Lyrics (R-LYR)

1. Lyrics without timestamps MUST NOT be labelled or scrolled as synced. The fallback order is timed lyrics, then plain text labelled as not synced, then song information only.
2. Automatic matching MUST be conservative: normalized title and artist must match and the duration must be within 3 seconds. A different recording MUST NOT be chosen just to show some text. Duration is for matching only and MUST NOT stretch timestamps.
3. The per-song offset corrects a constant delay. It MUST NOT be used or advertised as a fix for a different recording.
4. Ads and ambiguous metadata MUST NOT be paired with lyrics; lyrics and controls pause during a detected ad.
5. Results that arrive for a previous track or query MUST be discarded. Changing the track cancels the pending search.
6. Display preferences (such as preferring Japanese lines) MUST NOT modify raw lyrics or the cache.
7. When the automatic acceptance rules change, the cache folder version MUST be bumped (`Lyrics-v2` → `Lyrics-v3`).
8. LRCLIB etiquette MUST be kept: an identifying `User-Agent`, serialized requests with a delay, `Retry-After` honored, no outage cached as "not found".
9. Lyrics MUST come from public sources that need no account: LRCLIB, visible YouTube captions, lyrics stored with the track in the Music app, or a file the user imports. Private endpoints that need the user's account token (such as Spotify's or Apple Music's synced lyrics) MUST NOT be used.

## Playback, sources, and commands (R-PLAY)

1. The latest player snapshot is the source of truth for position and state. The UI MUST NOT change playback state because a button was clicked; it waits for the next snapshot or acknowledgement.
2. Commands MUST carry the source, session, and track identity, and every layer (service worker, content script, desktop adapter) MUST re-check them. Seek MUST be validated against the duration and the source's capabilities.
3. Changing the selected source cancels any pending command.
4. Automatic mode follows a source that just started playing; a heartbeat from an already playing source MUST NOT steal the selection. Manual mode MUST NOT jump to another tab.
5. Unit tests MUST use deterministic fixtures, without network requests or a real browser.

## Privacy and security (R-SEC)

1. No telemetry or analytics. Outbound traffic is limited to LRCLIB and the allow-listed image hosts; adding a network destination needs a decision and a privacy note in the user guide.
2. The extension requests only `nativeMessaging` and runs only on `www.youtube.com` and `music.youtube.com`. Wider host access or new permissions need a written justification and a decision.
3. Ririku MUST NOT read cookies, passwords, tokens, or browsing history, and MUST NOT ask for Accessibility or Screen Recording permission without a proven need and a decision. Automation permission is requested only when the user enables a desktop player.
4. Page data (titles, captions, artwork URLs) is untrusted: size-limit and validate it in the extension and again in the app. It MUST NOT be executed or interpolated into shell commands or AppleScript; desktop adapters only embed identifiers that match a strict pattern.
5. The bridge MUST NOT open a network listener. The socket and native host manifest stay user-only, and both sides check the peer.
6. Logs MUST NOT record song history or full URLs by default, and MUST never record credentials.
7. Private or undocumented system APIs MUST NOT be the foundation of a feature.
8. Uninstall and cleanup steps MUST remove only Ririku's own files, never a shared folder such as `NativeMessagingHosts` or another app's cache.

## Compatibility (R-COMPAT)

1. The bundle identifier, native host name, extension `key` and ID, socket path, and cache paths MUST NOT change without a decision and migration notes in `CHANGELOG.md` (see [architecture](development/architecture.md#identifiers-and-files)).
2. The bridge protocol ignores unknown `kind` values on both sides; new fields and messages MUST keep older components working or bump `protocolVersion`.

## Text and documentation (R-DOC)

1. Interface text is written in English in code and MUST be translated into `Localization/id.lproj` and `Localization/ja.lproj` in the same change (`scripts/check-localization.py`). See [localization](development/localization.md).
2. Documentation and commit messages are in English. Commit subjects use `type (area): short description`.
3. When user-facing behavior changes, update `docs/user-guide.md` and its translations and the translated READMEs, or state clearly that the translations still need updating.
4. Changes are recorded in `CHANGELOG.md` under the unreleased version, not as per-version notes in other documents.

## Honest reporting (R-HONEST)

1. Do not claim a build, test, integration, performance, or resource result without evidence. Report what was run and what was not.
2. `swift test` covers core logic, the app model, localization, and setup helpers with fixtures. UI rendering, real browser and desktop-player behavior, login items, and audio timing need manual checks, and a change MUST say which ones were not done.
3. Efficiency MUST NOT be claimed without measuring CPU, memory, wakeups, and network use on a real Mac.
