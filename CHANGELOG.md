# Changelog

All notable changes to Ririku are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org). Versions before 0.3.0 were private prototypes named Notch Box and were never published.

## [0.3.0] - Unreleased

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
