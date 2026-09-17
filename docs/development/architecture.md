# Architecture

This document describes how Ririku v0.3.0 works. The reasoning behind major choices is in the [decision log](../decisions.md); the history of earlier designs is in the [Indonesian archive](../archive/id/README.md).

## Overview

```text
YouTube / YouTube Music page (Chrome)
  player-state.js   MAIN world: reads the YouTube player's video ID, title, author
  content.js        isolated world: <video> state, captions, ads, buttons → snapshots; runs commands
      ↕ chrome.runtime messages
background.js       service worker: tracks tabs, forwards snapshots, validates commands, reconnects
      ↕ Chrome native messaging (stdio)
RirikuHost          native messaging host inside Ririku.app
      ↕ Unix domain socket /tmp/ririku-<uid>/bridge.sock
Ririku.app          BridgeServer → AppModel → SwiftUI views in an AppKit panel
                    LyricsService (LRCLIB), ArtworkService, ChromeSetup, Localizer
```

Ririku is a menu bar (accessory) app without a Dock icon. The notch panel and the Setup window share one `AppModel`, which owns playback sessions, source selection, lyrics state, preferences, and localization. Views read the model; they never talk to the browser directly.

## Swift targets

| Target | Responsibility |
| --- | --- |
| `RirikuCore` | Code without UI: `PlaybackSnapshot` validation and position estimate, `LRCParser` (parse, active line, Japanese display filter), `LyricsQuery` (title/artist normalization, matching, ranking), `Frames` and `LocalSocket` for the bridge, `IslandMotion` interpolation. |
| `Ririku` | `main.swift` (app delegate, `NSPanel`, menu bar, hover, resize animation), `AppModel`, `PlayerView`, `SetupView`, `DecorativeSpectrum`, `BridgeServer`, `MediaServices` (HTTP client, LRCLIB, artwork), `ChromeSetup`, `Localization`. |
| `RirikuHost` | Relays framed messages between Chrome (stdin/stdout) and the app socket. If the app is not running and the first message is `openSetup`, it launches the enclosing `Ririku.app` with `open -g` and retries for up to 4 seconds. |

## Bridge protocol

All messages are JSON objects with `"protocolVersion": 1` and a `kind`. Between `RirikuHost` and the app, each message is framed as a little-endian `UInt32` length followed by the JSON body, limited to 256 KiB (`Frames` in `RirikuCore`). The same framing is used on the host's stdio, as required by Chrome native messaging.

The socket lives in `/tmp/ririku-<uid>` (directory mode 0700, socket 0600). Both sides check the peer's user ID. A lock file (`bridge.sock.lock`) prevents a second app instance from taking over, and the app accepts one host connection at a time, so one Chrome profile can be connected.

### Extension → app

| `kind` | Fields | Notes |
| --- | --- | --- |
| `snapshot` | `sessionId`, `sourceId` (`tab:<id>`, set by the service worker), `sourceLabel`, `sequence`, `trackId`, `title`, `artist`, `position`, `duration` (null for live), `playbackRate`, `state` (`playing`, `paused`, `buffering`, `ended`), `isAdvertisement`, `capabilities` {`playPause`, `previous`, `next`, `seek`}, `artworkURL`, `captionEnabled`, `captionText` | Sent on media events (throttled to 100 ms) and every second as a heartbeat. The app rejects invalid values, text over its limits (title/artist 500 characters, artwork URL 2048, captions 4000 bytes), and sequences not newer than the last one for that session. |
| `remove` | `sourceId`, `sessionId` | The media element disappeared, the tab closed, or the page started a new session. |
| `ack` | `commandId`, `ok` | Result of a command. The app shows an error if no ack arrives within 3 seconds. |
| `openSetup` | | From the popup's **Open app Setup** button. |
| `extension` | `version` | Sent after connecting (after any pending `openSetup`). The app accepts only numeric versions and compares it with the bundled extension. |

### App → extension

| `kind` | Fields | Notes |
| --- | --- | --- |
| `hello` | `language` | Sent when the host connects; marks the bridge as connected and sets the popup language. |
| `preferences` | `language` | Sent when the interface language changes. |
| `command` | `commandId`, `sourceId`, `sessionId`, `trackId`, `action` (`toggle`, `previous`, `next`, `seek`), `position` | The service worker only forwards commands for a source seen in the last 5 seconds with a matching session and track; the content script checks them again. |

The service worker reconnects with exponential backoff up to 15 seconds and shows a `!` badge while disconnected. It rejects messages from other frames, origins, or oversized payloads (16,000 characters). Unknown kinds are ignored on both sides, which keeps older and newer components from crashing each other.

Metadata from `player-state.js` (MAIN world) is treated as untrusted page data: the content script only accepts `ririku-player-metadata-v1` messages from the same window and origin with an 11-character video ID and bounded strings, and ignores them after 2.5 seconds. When the player getter is unavailable, it falls back to the YouTube Music player bar link and then the page URL.

## Source selection

A session is fresh while its last snapshot is under 5 seconds old; stale sessions are removed.

- **Automatic** (default): switch to a session that just began playing (state changed to `playing`, an ad ended, or the track changed). A heartbeat from a tab that was already playing does not steal the selection. If the selected session disappears, pick a fresh playing session, otherwise the most recent one.
- **Manual:** keep the chosen tab. If that tab reconnects with a new session (for example after a refresh), select it again; never jump to another tab.

Changing the source cancels any pending command.

## Playback clock and lyric lines

The latest snapshot is the source of truth. While `playing` and not an ad, the position advances from the snapshot's `position` by the elapsed time since it was received (monotonic `systemUptime`) multiplied by `playbackRate`, capped at 5 seconds; otherwise it stays still. The UI samples it every 0.25 seconds.

The active lyric line is the last line whose time is at or before `position − offset` (binary search). A positive per-song offset delays lyrics. Offsets are stored per `YouTube:<videoId>`, shared between YouTube and YouTube Music, limited to ±60 seconds, and not applied to captions.

With **Prefer Japanese on shared timestamps**, `LRCParser.displayLines` hides Latin-only lines that share an exact timestamp with a line containing kana or kanji, but only when the track contains kana. Raw lyrics and the cache are never modified; the filtered result is cached in memory per track and invalidated when lyrics or the preference change.

## Lyrics pipeline

1. On a new track with complete metadata, wait 650 ms (metadata often changes right after navigation).
2. Build a `LyricsQuery`: trim decorative labels ("Official Music Video", `【Artist】` prefixes, "- Topic" channels, bilingual `日本語 - English` titles) while keeping version markers such as live or remix.
3. Look up `GET /api/get` with title, artist, and rounded duration, then `GET /api/search` with title and artist unless the exact result is instrumental. A search failure is ignored if a candidate already exists.
4. Accept only records whose normalized title and artist match and whose duration is within 3 seconds; prefer timed lyrics, then the closest duration.
5. Cache the result as JSON named by the SHA-256 of the query in `~/Library/Caches/io.github.lanstheprodigy.ririku/Lyrics-v2`: found results for 30 days, not found for 30 minutes, at most 300 files (oldest removed). Bump the folder version when the acceptance rules change.

Requests to LRCLIB are serialized with at least 350 ms between them and a `User-Agent` of `Ririku/<version> (https://github.com/ghufronakbar/Ririku)`. HTTP 429 sets a cooldown from `Retry-After` (default 60 s). Network errors retry after 30 seconds while the track is still active. Results for an old track or query are discarded.

Manual **Search and choose a lyrics version** uses `GET /api/search?q=` and ranks all results by absolute duration difference (unknown durations last). A manual choice, an imported LRC file (UTF-8, ≤1 MB), or **Back to automatic result** apply only to the current track and last until the app quits.

**Lyrics source** decides what is shown: `auto` prefers timed LRC lines and falls back to captions when CC is on; `lrclib` never shows captions; `caption` shows only captions and never queries LRCLIB. Captions are read from the visible YouTube caption elements, coalesced for 40 ms, and cleared during seeks, navigation, and ads.

## Network clients

`SafeHTTPClient` uses an ephemeral `URLSession` without cookies, credentials, or URL cache, accepts only HTTPS on port 443 to an allowlist of hosts (also enforced on redirects), times out after 15/20 seconds, and aborts responses over 2 MB. LRCLIB uses `lrclib.net`. Artwork is limited to YouTube/Google image hosts, source images up to 8192 px, downsampled to 256 px, with an in-memory cache of 40 images; failed downloads retry after 30 seconds.

## Panel and motion

- The panel is a borderless, non-activating `NSPanel` at status bar level on all Spaces, placed at the top center of the first screen with a top safe-area inset (the notch), otherwise the main screen. The notch width comes from `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` (minimum 180 pt).
- `AppModel.panelSize` computes the frame from the expanded state, width preferences (never narrower than the notch plus 100/120 pt, never wider than the screen minus 24 pt), lyric lines, notices, and errors.
- Frame changes use `IslandMotion`: 0.32 s smoothstep interpolation driven by a 60 Hz timer that runs only during the resize and keeps the top edge fixed. Reduce Motion or the animation setting disables it.
- Hover opens after 150 ms and closes after 350 ms unless the panel has keyboard focus. Track changes do not expand the panel.
- `DecorativeSpectrum` animates five synthetic bars at up to 24 Hz only while playing; it never captures audio.

## Localization

Interface text is written in English in code and translated through `Localization/<code>.lproj/Localizable.strings`. `Localizer` loads the chosen `.lproj` sub-bundle directly so the language can change without restarting. Stored statuses are `UIText` (key plus arguments) and are translated at render time. See [localization.md](localization.md).

## Chrome setup

The extension manifest contains a public `key`, so the unpacked extension always has the ID `bmmbkmngcmjoihlcmehlnfpedhoefofi`; this was confirmed in Chrome on 2026-09-18, with the app reporting the connected extension version. `ChromeSetup`, triggered only by Setup buttons:

- writes `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/io.github.lanstheprodigy.ririku.bridge.json` (mode 0600) pointing to `RirikuHost` inside the running bundle and allowing only that extension ID;
- reports whether the manifest is missing, points to another copy of the app, or is current;
- refuses to register while the app runs from App Translocation (a temporary path used for quarantined apps that were not moved), because that path disappears;
- copies the bundled extension to `~/Library/Application Support/Ririku/Chrome Extension` through a staging folder and `replaceItemAt`.

## Identifiers and files

| Item | Value |
| --- | --- |
| Bundle identifier and preferences domain | `io.github.lanstheprodigy.ririku` (kept from the first Ririku build; the repository later moved to the `ghufronakbar` account and the identifiers were deliberately left unchanged so existing installations keep their settings) |
| Native messaging host name | `io.github.lanstheprodigy.ririku.bridge` |
| Extension ID | `bmmbkmngcmjoihlcmehlnfpedhoefofi` |
| Socket directory | `/tmp/ririku-<uid>` |
| Lyrics cache | `~/Library/Caches/io.github.lanstheprodigy.ririku/Lyrics-v2` |
| Extension copy | `~/Library/Application Support/Ririku/Chrome Extension` |

Changing any of these breaks existing installations; document migration steps in the changelog if you must.

## Security and privacy boundaries

- The extension requests only `nativeMessaging` and runs only in the top frame of `www.youtube.com` and `music.youtube.com`. It does not read cookies, credentials, or history, and it does not capture audio.
- Page data (titles, captions, artwork URLs) is untrusted: it is size-limited and validated in the extension and again in the app, never executed, and artwork URLs are restricted to image hosts.
- The bridge has no network listener. The socket and native host manifest are user-only, and the host only accepts the fixed extension ID. Because the extension key is public, another unpacked extension could reuse the ID, but only if the user installs it; the bridge only exposes player snapshots and a small command set.
- Outbound traffic is limited to LRCLIB and image hosts. There is no telemetry.

Report vulnerabilities as described in [SECURITY.md](../../SECURITY.md).
