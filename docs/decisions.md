# Decision log

This log records product decisions and notable technical choices. The rules that follow from them are in [rules.md](rules.md). The Indonesian planning history up to v0.3.0 was removed from the working tree on 2026-09-19 and remains in Git history.

- **Decisions** (D-numbers) were agreed by the project owner.
- **Technical choices** were made while implementing and can be revisited in an issue or pull request.
- An implemented feature is not automatically an agreed decision, and a mockup or proposal is not an implemented feature.

When a decision changes, add a dated entry here, update the affected documents, and explain why.

## Decisions

| ID | Decision | Date and reason |
| --- | --- | --- |
| D-001 | Ririku is a simple, native macOS app. | 2026-09-17. Personal use first; no complex utility suite. The "no utility suite" part was replaced by D-017 on 2026-10-05; the app stays native. |
| D-002 | Focus on music controls, synced lyrics, and a polished notch UI with smooth animation. | 2026-09-17. Core need. Out of scope: word-by-word karaoke, audio downloads, DRM bypass, file shelf, clipboard, calendar, weather, cloud accounts. On 2026-10-05, D-017 brought the file shelf, clipboard, and calendar into scope; the rest stays out. |
| D-003 | Target players: YouTube and YouTube Music in Chrome, Apple Music, and Spotify desktop apps. | 2026-09-17. Requested player coverage; desktop adapters still need validation. |
| D-004 | Chrome is the first priority. | 2026-09-17. The owner's daily player. |
| D-005 | A companion Chrome extension is allowed. | 2026-09-17. Needed to read and control the web player. |
| D-006 | Documentation came before mockups and implementation. | 2026-09-17. Planning phase. |
| D-007 | Visual settings are adjustable in a separate Setup window. | 2026-09-17. Owner direction. |
| D-008 | The source picker lives in Setup, not in the notch panel. | 2026-09-17. Keeps the panel focused on music and lyrics. Still applies after D-017: every setting stays in Setup. |
| D-009 | Move from mockup review to a native prototype. | 2026-09-17. Not an approval of every later technical detail. |
| D-010 | Automatic lyrics, real artwork, automatic source selection and recovery, and an extension popup with status. LRC import is a fallback. | 2026-09-17. After first user testing. |
| D-011 | Interface in English, Bahasa Indonesia, and 日本語; follow the system language with English fallback, plus a live language picker in Setup. | 2026-09-17. Chosen after a feasibility study. |
| D-012 | Open source under the name **Ririku**, MIT license, maintained by `lanstheprodigy` at `github.com/ghufronakbar/Ririku`. | 2026-09-17. "Notch Box" collided with the NotchBox app on the Mac App Store; "Ririkku" collided with a lyrics music player at ririkku.com. No music or lyrics app named Ririku was found in web searches (not a formal trademark search). MIT is simple and there are no third-party dependencies. |
| D-013 | Free distribution: ad-hoc signed GitHub releases without notarization, extension installed with Load unpacked and a tutorial, no migration of Notch Box settings. | 2026-09-17. The owner does not want paid programs (Apple Developer Program, Chrome Web Store). |
| D-014 | English is the primary documentation language; user-facing documentation is also available in other languages. | 2026-09-17. Open-source audience. |
| D-015 | Ririku can open itself at login, as an option that is off by default. | 2026-09-18. Owner request after the open-source preparation. Implemented with `SMAppService`; macOS keeps the state and can ask the user for approval. |
| D-016 | Support the other Chromium browsers (Brave, Edge, Vivaldi, Opera, Chromium, Arc) with the same extension, one connected browser at a time. | 2026-09-18. Owner request. Only the host manifest folder and the extensions address differ per browser, so the cost is small; simultaneous browsers would need per-connection routing in the bridge and was deliberately left out. |
| D-017 | Ririku becomes a multipurpose notch app. Music controls and synced lyrics stay the core, and the panel gains tabs with widgets and tools: system stats, network speed, battery, clock and date, Pomodoro, countdown, stopwatch, notes, counter, days left, water, apps, shortcuts, bookmarks, a file tray with AirDrop, clipboard history, a calendar, a camera mirror, and translation. | 2026-10-05. Owner request: NotchBox, the reference app, charges for several of these features, and Ririku should offer them free and open source. The earlier limits were an initial guard against feature creep. Still out of scope: word-by-word karaoke, downloads, DRM bypass, an embedded web browser, weather, and paywalls. See [Multipurpose notch app](#multipurpose-notch-app--2026-10-05). |
| D-018 | The panel layout is customizable and has a default: a Home tab (Music, wide, and System) and a Tray tab; Clipboard and Translate become tabs when turned on; other widgets start off. A layout is a list of tabs, each a page of small or wide widgets or a single tool. It is edited in Setup with a live preview and can be reset. Editing directly in the panel is a future plan. | 2026-10-05. The owner asked for a customizable layout that still has a sensible default. Editing in Setup keeps settings out of the panel (D-007). |
| D-019 | Translate uses Apple's on-device Translation framework on macOS 15 and later. The minimum system stays macOS 14, where Translate is disabled. A display-only lyric translation follows the Translate tab. An AI assistant is a future plan that needs its own decision; a Web View tab is not planned. | 2026-10-05. On-device translation needs no API key, no new network destination, and no dependency. `TranslationSession` requires macOS 15 (checked in the macOS 15.5 SDK); macOS 14.4 only offers the system translation popover. |
| D-020 | Widgets that need a permission or keep personal data are opt-in and start off. Calendar (read-only, EventKit) and Camera (AVFoundation) ask for permission only when turned on. Clipboard history keeps text and images, at most 50 items, on this Mac across restarts, and skips items marked as concealed, such as copied passwords. | 2026-10-05. Privacy by default, the same pattern as the Spotify and Apple Music connections. |
| D-021 | The Tray keeps references to files instead of copies, so an item disappears when its file is deleted. Bookmarks open in the default browser. Widget notices (a finished timer, charging started) appear briefly in the compact island and never expand the panel. | 2026-10-05. Keeps the user's files where they are, avoids an embedded browser, and keeps the panel from opening by itself (R-UI-3). |
| D-022 | Setup gains general settings: the display for the panel (automatic or a chosen display), hover and close delays, Dock and menu bar icons, haptic feedback, a keyboard shortcut to open the panel (off by default), a tutorial, and an About page. Not taken: a logo in the notch, and upgrade or premium pages. | 2026-10-05. Owner request from the NotchBox comparison. A logo would sit under the notch (R-UI-5), and Ririku has no paid plan (R-SCOPE-3). |
| D-023 | The name stays **Ririku**. When the widgets ship (0.4.0), the tagline becomes "Music, lyrics, and handy widgets in your Mac's notch." | 2026-10-05. The name is established (D-012). Changing the tagline before the widgets exist would describe features the app does not have. |
| D-024 | The work follows the staged plan in the [roadmap](roadmap.md): rules first, then a refactor that changes no behavior, then general settings, the widget framework, local widgets, the Tray and clipboard, and finally the calendar, camera, and translation. | 2026-10-05. Keeps each pull request reviewable and lets the existing tests guard the refactor. |
| D-027 | Translate and lyric translation details: the Translate tab detects the source language unless one is chosen and translates 0.6 s after typing stops or on Return; its target defaults to the interface language. Languages are downloaded only from Setup; the panel translates downloaded languages and otherwise points to Setup. Lyric translation has its own switch and target in **Setup → Lyrics**, translates a song's synced lines once in memory, leaves lines already in the target language, and shows each translation under the active line in the expanded panel only. | 2026-10-05. Owner choices for roadmap stage 6. The system's download prompt shows reliably in a normal window, unlike the non-activating notch panel (see the open questions). Keeping the compact island unchanged keeps it the size of the notch. |
| D-026 | Calendar and camera details: the Calendar widget shows today's events that have not ended, or tomorrow's once today has none left, timed events before all-day ones (small: the next event; wide: up to three). It reads every calendar except those turned off in Setup, so new calendars appear, and clicking it opens the Calendar app. The camera turns on only when the Camera widget is clicked in the open panel, never by itself or in Setup's preview. Both ask for their permission when the widget is added in **Setup → Layout**. | 2026-10-05. Owner choices for roadmap stage 6. Starting the camera on its own would turn on the camera light each time the pointer passes the notch while the widget is on Home. Setup is a normal window, so the system prompt shows reliably there. |
| D-025 | Tray and clipboard details: a layout saved before the Tray existed gets the Tray tab once; a file dragged onto the notch opens the panel on the Tray tab; clicking a file on the Tray opens it with its default app; turning clipboard history off deletes the history. | 2026-10-05. Owner choices for roadmap stage 5. The drag is a user gesture like hover, so R-UI-3 lists it. |

Earlier approved requirements from the planning phase: selectable lyrics source with per-song offset and duration-based version picking (v0.2.2); lyric visibility, 1/2/3 lines, adjustable width, and smoother transitions (v0.2.3); top-anchored resizing, no auto-expand on track change, short "not found" notice, decorative spectrum, and Japanese line preference (v0.2.4). Their lasting constraints are in [rules.md](rules.md).

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
| Documentation | English README, user guide, developer docs, and binding project rules; Indonesian and Japanese README and user guide; community files added | Translations name the English version they follow. |
| Repository settings | Private vulnerability reporting enabled and the `translation` label created on 2026-09-19, so `SECURITY.md` and every issue template work; description and topics set | Changed by the maintainer in the GitHub settings. |
| CI and releases | GitHub Actions on macOS runners: checks, `swift test`, and a bundle build on every push, plus tag-driven draft releases with a zip and checksum | Uses only first-party actions (`actions/checkout`, `actions/upload-artifact`) and `gh`. |
| Launch at login | `SMAppService.mainApp` registers the app bundle itself; the state is read from macOS instead of being stored in the preferences; unavailable outside the `.app` and while translocated | No helper tool or launch agent. Registration by an ad-hoc signed build still needs validation on a downloaded release. |
| Keyboard shortcut | Carbon `RegisterEventHotKey` with an application event handler; the shortcut needs Command, Option, or Control and is stored as JSON | Public API that needs no Accessibility permission (R-UI-17), unlike a global `NSEvent` monitor or an event tap. On 2026-10-05, a probe on macOS 15.7, without Accessibility permission, registered ⌥⌘N successfully. |
| Panel display | The chosen display is stored by its CoreGraphics display UUID (`CGDisplayCreateUUIDFromDisplayID`) plus its name; a disconnected choice falls back to automatic placement | Display numbers can change after a restart or reconnection; the UUID does not. |
| Dock icon and menus | The activation policy switches between `.accessory` and `.regular` at runtime while `LSUIElement` stays on; a main menu with app, Edit, and Window menus is always installed | Keeps the default start without a Dock icon, and gives Setup the standard editing shortcuts in both modes. |
| Panel layout | JSON under the `panelLayout` preference, decoded entry by entry and sanitized against the widget kinds the app knows | One unreadable or future entry never loses the whole layout (R-WID-2). The default layout is Home and the Tray (D-018, D-025). |
| System widget | Mach host statistics for processor and memory, volume capacity for the disk; sampled every 2 s only while a System widget is visible, the disk every 30 s | Memory counts app memory, wired, and compressed pages, as Activity Monitor does. Resource use still needs measuring (R-HONEST-3). |
| Local widgets | One `widgetData` JSON preference plus `widgetNotes`; timers store the start date and counted time and schedule only their end | Timers survive the app quitting without ticking (R-WID-4). The network widget counts `en` interfaces only, so VPN tunnels are not counted twice. Shortcuts run through `/usr/bin/shortcuts` with an argument list (R-WID-9). |
| Tray | macOS bookmarks plus paths in the `trayItems` preference; refreshed when the Tray appears | Follows renamed and moved files without copying them (R-WID-7). |
| Clipboard history | `NSPasteboard.changeCount` checked every 0.5 s while on; JSON and PNG files in `Application Support/Ririku/Clipboard` | macOS offers no pasteboard change notification. Text over 100,000 characters and images over 20 MB are not kept. |
| Calendar widget | EventKit with full access (`requestFullAccessToEvents`), events from the start of today to the end of tomorrow, reloaded on `EKEventStoreChanged` and at the next start, end, or midnight while a Calendar widget is visible | macOS 14 offers full or write-only access, and only full access can read events; Ririku never writes (R-WID-8). The `hiddenCalendars` preference stores the calendars turned off, so new ones are shown. |
| Camera mirror | `AVCaptureSession` with the default camera and an `AVCaptureVideoPreviewLayer` flipped by a layer transform; made on the first click and started and stopped on a serial queue | Nothing is set up until the user clicks, and the default camera is chosen again on each start, so a newly connected camera is used. No frames are read by Ririku itself (R-WID-5). |
| Permission prompts | `NSCalendarsFullAccessUsageDescription`, `NSCameraUsageDescription`, and `NSAppleEventsUsageDescription` in `Info.plist`, translated in `InfoPlist.strings`; `check-localization.py` requires a translation for each | macOS shows these texts in its own prompt, in the system language. |
| Translation | `TranslationSession` from SwiftUI's `translationTask`, the only way to get one on macOS 15; `LanguageAvailability` to check that a pair is downloaded; `NLLanguageRecognizer` to find the source language | A session cannot be made directly before macOS 26 (checked in the macOS 15.5 SDK), so the Translate tab and the notch panel hold the tasks. Detecting the language first lets the panel check the pair and never start a download (D-027). On 2026-10-05, macOS 15.7 offered 21 languages, including Indonesian and Japanese. |
| Lyric translation | One batch per song with a request per line, results in memory for the last 20 songs, keyed by the track, the target, and the lines; lines already in the target language are found with detection limited to the two languages plus an alphabet check | The panel window is always on screen, so it holds the task. Open detection with a confidence limit passed on macOS 15.7 but failed CI on macOS 26.6 for "I love you", and took "Baby" for Slovak. A result for other lines is dropped (R-LYR-5); the lyrics and the cache never change (R-LYR-6). |
| Tests | Swift Testing suites in `Tests/RirikuCoreTests` and `Tests/RirikuTests`, fixtures only | Executable targets can be tested with SwiftPM, so the app model and the browser setup are covered without a UI. |

## Open questions

| Question | Status |
| --- | --- |
| Spotify desktop and Apple Music Automation approval, playback timing, and controls | Implemented with AppleScript; real playback validation pending |
| Behavior on external displays, full screen, Spaces, and Macs without a notch | Open; **Setup → General** can now choose the display (2026-10-05), but placement on an external or notch-less display is untested because only the built-in display was connected |
| Gatekeeper experience for downloaded ad-hoc builds on each macOS version, and whether updates require confirming again | Validated on 2026-09-18 with the 0.3.1 release zip on macOS 15.7.2: the "Not Opened" dialog, **Done**, then **Open Anyway** in Privacy & Security worked as the user guide describes. macOS 14 and confirming again after an update are still untested |
| Universal (Intel) builds | Open |
| Test coverage for SwiftUI views, the browser extension JavaScript, and end-to-end bridge behavior | Open; `swift test` now covers core logic, the app model, localization, and the browser setup helpers |
| Whether Brave, Edge, Vivaldi, Opera, Chromium, and Arc really accept the shared extension ID and native host | Needs validation on a real install; Arc's `NativeMessagingHosts` folder is unconfirmed |
| Two browsers connected at the same time | Open; the bridge accepts one host connection, which would need per-connection command routing and `sourceId` prefixes |
| Launch at login registered by an ad-hoc signed, non-notarized build | Needs validation, including the approval prompt in System Settings |
| Whether watching the pasteboard for clipboard history shows a privacy alert on macOS 26 and later | Open; to check before the clipboard ships (roadmap stage 5). No alert is expected on macOS 15 |
| Whether the system prompt to download translation languages appears correctly from the non-activating notch panel | Avoided: languages are downloaded from Setup (D-027). Whether the prompt appears there still needs a check on a real Mac |
| Whether Calendar and Camera access survive an update of the ad hoc signed app, or macOS asks again | Open; the user guide says macOS may ask again |
| CPU, memory, and wakeups of the widgets on a real Mac | Open; to measure before any efficiency claim (R-HONEST-3) |

### Spotify desktop connection — 2026-09-18

Use Spotify's local scripting interface for the requested desktop integration, without a Web API account, OAuth flow, or browser extension. Connection is opt-in and requires macOS Automation permission. Reuse the existing source-selection and LRCLIB pipeline. Limit this first adapter to standard music track URIs; ads, local files, and podcasts are not supported as songs. This adds `i.scdn.co` solely for Spotify artwork and no audio capture.

### Apple Music desktop connection — 2026-09-18

Connect the Music app through its local scripting interface, sharing one AppleScript adapter with Spotify: opt-in, macOS Automation permission, no MusicKit developer token or account. Tracks are identified by their persistent ID and commands recheck it. Artwork is read from the track's embedded data instead of an image server, so no new network host is added. Radio stations and streams without a duration are not treated as songs.

Lyrics stay on LRCLIB. Synced lyrics in Spotify and Apple Music are only reachable through private endpoints that need the user's account token, so they are not used. As a local fallback, the Music app's plain `lyrics` track property is shown when LRCLIB has nothing (2026-09-18).

### Code of conduct — 2026-09-18

No separate code of conduct. The basic conduct expectations in CONTRIBUTING.md are enough for a small spare-time project, and a standalone document such as the Contributor Covenant would need a dedicated contact address for reports.

### Project rules replace the planning archive — 2026-09-19

The owner asked for documentation that other developers and AI agents can follow as rules. The rules that still applied in the Indonesian planning documents (`docs/archive/id/`) were collected with the agreed decisions into [rules.md](rules.md), with IDs that pull requests can cite, and the archive was removed. It mixed proposals that were later changed with agreed requirements, so an agent could mistake an outdated proposal for a rule. The history remains in Git. `AGENTS.md` now makes `rules.md` required reading and tells agents to stop and ask when a request conflicts with a rule.

### Multipurpose notch app — 2026-10-05

The owner compared Ririku with NotchBox, a commercial notch app installed on their Mac. Its panel has Home, Tray, and Web View tabs, and its settings offer widgets (waveform, date, Pomodoro, countdown, stopwatch, camera, network, calendar, apps, water, bookmarks, notes, days left, counter, shortcuts, system) and pages for clipboard, translation, an AI assistant, battery, and keyboard, several of them behind a paid plan. The scope limits in D-001 and D-002 were the initial guard against feature creep, and the owner decided to lift them so that Ririku offers these features for free and as open source (D-017). Music controls and synced lyrics stay the core and the default.

The rules changed with it:

- R-SCOPE-2 lists what stays out: karaoke, downloads, DRM bypass, an embedded web browser, weather, and new online services without a decision. R-SCOPE-7 forbids copying another app's code, icons, artwork, or text.
- R-UI-1 lets the panel hold widgets and tools while every setting stays in Setup.
- R-UI-3 and R-UI-6 cover widget notices.
- R-UI-16 and R-UI-17 cover hidden icons and the keyboard shortcut.
- The new R-WID section covers the default layout, opt-in permissions, background work, the camera, clipboard, Tray, calendar, shortcuts, translation, and bookmarks.
- R-SEC-1, R-SEC-3, R-SEC-6, R-SEC-8, R-COMPAT-3, and R-HONEST-2 were extended.

Not taken from NotchBox: the Web View (not wanted), the AI assistant (a future plan that needs its own decision about a provider), the upgrade and premium pages (R-SCOPE-3), and the logo in the notch (R-UI-5). Some NotchBox pages (Clipboard, Translate, AI Assistant, Battery, Keyboard) were only seen by name in its sidebar, so Ririku's versions are designed from the feature names rather than from NotchBox's screens.
