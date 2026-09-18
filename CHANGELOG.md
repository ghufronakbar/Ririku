# Changelog

All notable changes to Ririku are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org). Versions before 0.3.0 were private prototypes named Notch Box and were never published.

## [0.3.1] - Unreleased

### Fixed
- The expanded panel closes once the pointer leaves it, even after clicking a control such as pause. Closing now follows the pointer position instead of a hover exit that SwiftUI could miss, and a panel opened from the menu stays open until the pointer has visited it.
- YouTube Music artwork is keyed to the playing video rather than an unverified player-bar image that can retain the previous album.
- YouTube Music uses the visible song clock instead of an accumulated media timeline. Seeking maps song-relative positions through the player API and rejects stale track commands.
- Track metadata changes reset the Setup lyric search, including metadata corrections under the same video ID.
- LRCLIB retries temporary 502/503/504 responses with bounded backoff, respects Retry-After, and does not cache an outage as missing lyrics.

### Added
- Opt-in Apple Music connection to the Music app, sharing the Spotify AppleScript adapter: persistent-ID–validated commands, locally read artwork, and the same source selection and LRCLIB lyrics. When LRCLIB has none, plain lyrics saved with the track in the Music app are shown unsynced. Requires macOS Automation permission; live permission/playback validation is still pending. Radio streams without a duration are not supported as songs.
- Opt-in Spotify desktop connection using local AppleScript polling and track-validated playback commands. Shares source selection, LRCLIB lyrics, artwork, and automatic accent; requires macOS Automation permission. Browser disconnects preserve the Spotify session. Live permission/playback validation is still pending; podcasts, local files, and ads are not supported as songs.
- **Auto — from artwork** accent color: a cached dominant-color tint with readable brightness, Neutral fallback, and a transition that respects animation and Reduce Motion settings. Existing manual color preferences are preserved.
- Synced lyric rows slide upward on adjacent lines; seeks snap and Reduce Motion disables the animation.
- Offline regression tests for browser clock/seek transitions and lyrics service recovery. Real Chrome playback and animation rendering still need manual verification.
- **Setup → Startup:** **Open Ririku at login**, off by default. It registers the app bundle with `SMAppService`, so no helper tool or Terminal command is needed, and it stays unavailable while the app runs from a temporary location.
- **Other Chromium browsers:** Setup registers the native host for every installed browser it knows (Chrome, Brave, Edge, Vivaldi, Opera, Chromium, Arc) in one click, names them under step 1, and offers each browser's own extensions address. The native host reports which browser launched it, so the panel and step 4 name it. One browser profile is connected at a time, and only Chrome is verified so far.

### Changed
- **Long lyric lines are no longer cut off.** When a song has a line too long for the island, the current line is given two rows while the previous and next lines stay on one; a line that overflows by a little shrinks slightly instead of wrapping. The measurement happens once per song and island width, so the island keeps a steady height for the whole song instead of resizing line by line.
- **The expanded panel is now exactly as tall as its content.** Its height was a fixed 200 pt guess that left 21 pt of empty black space under the transport buttons; it is now the sum of the rows `PlayerView` draws, which are named once in `ExpandedLayout` and shared by the view. Spacing and the bottom padding are tighter and the transport buttons are 32 pt, so the panel is about 35 pt shorter (199 pt without lyrics, 285 pt with three lyric lines). A command error also gets a correctly sized row instead of borrowing that slack.
- **The compact island now matches the physical notch.** Its width and height are stored as an addition to the measured notch instead of absolute values, so the default fits the notch exactly on any Mac and nothing shows beside the camera housing. Artwork and the spectrum sit on the left and right edges and come out from behind the notch as the island grows, **Setup → Appearance** gained **Compact island height**, and **Reset size** became **Reset to the notch size**. The notch width is measured instead of assuming at least 180 pt, and the old `compactWidth` preference is dropped.
- While playback is paused, the compact island keeps the artwork and the spectrum but drops the lyrics, so it shrinks back to the notch; the expanded panel still shows them.
- **Setup → Chrome connection** is now **Setup → Browser connection**, and interface text that named Chrome now names the browser. The extension is listed as **Ririku — Browser Bridge**; reload it once from `chrome://extensions` after updating.

## [0.3.0] - Unreleased

Verified on 2026-09-18: the Chrome connection completed from Setup without Terminal, the app reported the connected extension version, and GitHub Actions CI passed. The Gatekeeper flow for a downloaded release is still untested.

### Changed
- **Renamed the app to Ririku.** New bundle identifier `io.github.lanstheprodigy.ririku`, native messaging host `io.github.lanstheprodigy.ririku.bridge`, socket directory `/tmp/ririku-<uid>`, and cache folder. Settings from Notch Box are not migrated, and extension 0.2.x does not work with this version.
- The documentation is now in English, with the README and user guide also in Bahasa Indonesia and Japanese. The original Indonesian planning documents moved to `docs/archive/id`.

### Added
- MIT license.
- **Setup → Chrome connection:** register the native host, copy the extension, and check the connection without using Terminal. Registration is blocked while the app runs from a temporary download location.
- The extension has a fixed ID, reports its version, and Setup warns when it is older than the one bundled with the app.
- User guide, developer documentation, contributing guide, security policy, and decision log.
- GitHub Actions: CI that builds the app and checks translations, versions, documentation, and the extension on every push and pull request; a release workflow that builds a tag into a draft release with a zip and SHA-256 checksum.
- Issue and pull request templates, and `scripts/check-version.py`, `scripts/check-docs.py`, and `scripts/release-notes.py`.
- **Setup → Startup:** **Open Ririku at login**, off by default. It registers the app bundle with `SMAppService`, so no helper tool or Terminal command is needed, and it stays unavailable while the app runs from a temporary location.
- Automated tests: `swift test` runs 91 Swift Testing cases for the LRC parser, playback clock, lyrics matching, bridge framing, island motion, localization, Chrome setup, launch at login, source selection, commands, and preferences. CI and the release workflow run them.
- Maintainer contact links in the README.
- Repository links point to `github.com/ghufronakbar/Ririku`; app identifiers keep `io.github.lanstheprodigy.ririku` on purpose, so no re-registration is needed.

## [0.2.5] - 2026-09-17

### Added
- Interface in English, Bahasa Indonesia, and Japanese. It follows the macOS language by default and can be changed live in Setup.
- The extension popup follows the app's language.

## [0.2.4] - 2026-09-17

### Added
- Decorative spectrum that settles when playback pauses (no audio capture).
- **Prefer Japanese on shared timestamps** hides romaji lines that share a timestamp with Japanese lines.

### Changed
- The island grows sideways and downward with its top edge fixed.
- Track changes no longer expand the panel. Lyric search status moved to Setup, with a short "Lyrics not found" notice in the island.

## [0.2.3] - 2026-09-17

### Added
- Show or hide lyrics in the island, 1/2/3 lyric lines, and adjustable compact and expanded widths.
- Player metadata read from the YouTube player for more accurate track detection.

### Changed
- Smoother panel transitions that respect Reduce Motion.

## [0.2.2] - 2026-09-17

### Added
- Lyrics source picker: automatic, LRCLIB/LRC only, or YouTube subtitles only.
- Search and choose a lyrics version, sorted by duration difference.
- Per-song lyric offset of ±60 seconds.

## [0.2.1] - 2026-09-17

### Added
- Show YouTube captions (CC) as lyrics.

### Changed
- Better matching for bilingual and Japanese video titles.

## [0.2.0] - 2026-09-17

### Added
- Automatic synced lyrics from LRCLIB with a local cache.
- Real artwork thumbnails.
- Automatically follow the player that starts playing and recover after reconnecting.
- Extension popup with connection status and a button to open Setup.

## [0.1.0] - 2026-09-17

### Added
- Native notch panel with playback controls, seek, and lyrics; separate Setup window; local demo mode; LRC import.
- Chrome extension for YouTube and YouTube Music, native messaging host, and local socket bridge.
