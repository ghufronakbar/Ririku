# Developer documentation

This section is for people who want to build, change, or release Ririku. For using the app, see the [user guide](../user-guide.md). For how to propose changes, see [CONTRIBUTING.md](../../CONTRIBUTING.md).

| Document | Contents |
| --- | --- |
| This page | Prerequisites, repository layout, building, running, and verification |
| [architecture.md](architecture.md) | Components, bridge protocol, playback clock, lyrics pipeline, UI, and security |
| [localization.md](localization.md) | How interface text is translated and how to add a language |
| [releasing.md](releasing.md) | Versioning and publishing a release |
| [../decisions.md](../decisions.md) | Decision log |
| [../archive/id/](../archive/id/README.md) | Original Indonesian planning documents (history only) |

## Prerequisites

- macOS 14 or later.
- Xcode Command Line Tools with Swift 6.1 or later (`xcode-select --install`). Full Xcode is not required.
- `/usr/bin/python3` (included with the Command Line Tools) for the build and localization scripts.
- Google Chrome for end-to-end testing.
- Optional: Node.js to syntax-check the extension with `node --check`.

There are no third-party Swift or JavaScript dependencies.

## Repository layout

```text
Package.swift              SwiftPM package: Ririku, RirikuHost, RirikuCore
Sources/RirikuCore/        Shared, UI-free code: playback snapshot and clock, LRC parser,
                           lyrics query matching, bridge framing, Unix socket helpers, panel motion
Sources/Ririku/            macOS app: AppKit panel and menu bar, SwiftUI views, AppModel,
                           bridge server, LRCLIB/artwork clients, Chrome setup, localization
Sources/RirikuHost/        Chrome native messaging host: stdin/stdout ↔ Unix socket relay
extension/                 Chrome extension (Manifest V3): content scripts, service worker, popup, icons
Resources/                 AppIcon.png: square source artwork for the app and extension icons
Localization/              App interface translations (<code>.lproj/Localizable.strings)
Tests/                     Swift Testing suites for RirikuCore and the app target
scripts/                   build-app.sh, make-icon.swift, check-localization.py, check-version.py,
                           check-docs.py, release-notes.py, install-host.py
samples/                   Original LRC file used by the local demo
docs/                      User guide, developer docs, decision log, archive
.github/                   CI and release workflows, issue and pull request templates
build/                     Local app bundle output (ignored by Git)
```

## Build and run

```sh
bash scripts/build-app.sh
open build/Ririku.app
```

`build-app.sh` runs the localization check, builds a release configuration with SwiftPM, assembles `build/Ririku.app` (app executable, `RirikuHost`, `.lproj` folders, and a copy of `extension/` as `ChromeExtension`), writes `Info.plist`, and signs the bundle ad hoc. When `Resources/AppIcon.png` exists, `scripts/make-icon.swift` clips it to a rounded square on the macOS icon grid and writes `AppIcon.icns`. The extension icons in `extension/icons/` come from the same artwork and are committed; after changing the artwork, regenerate them with `for n in 16 32 48 128; do swift scripts/make-icon.swift Resources/AppIcon.png --png $n extension/icons/icon-$n.png; done`. Quit a running Ririku before rebuilding.

`swift build` alone is enough to check that the code compiles, but a bare executable has no bundle resources: it shows English text and cannot register the browser connection.

### Connecting a browser during development

Use **Setup → Browser connection** in the built app, exactly like a user (see the [user guide](../user-guide.md#3-connect-your-browser)). Alternatively:

1. On the browser's extensions page, enable **Developer mode**, click **Load unpacked**, and select the repository's `extension/` folder. The `key` field in `manifest.json` gives it the fixed ID `bmmbkmngcmjoihlcmehlnfpedhoefofi` in every Chromium browser.
2. Register the native host for `build/Ririku.app`:

   ```sh
   /usr/bin/python3 scripts/install-host.py
   ```

   Pass `--browser brave` (or `edge`, `vivaldi`, `opera`, `chromium`, `arc`) for another browser, `--app "/path/Ririku.app"` for another bundle, or an extension ID for a fork with a different key.

Load only one copy of the extension (repository folder **or** the copy made by Setup) in one browser at a time: the app accepts a single host connection, so a second browser stays disconnected. After changing extension files, click the extension's reload button and refresh YouTube tabs.

### Debugging

- **App logs:** run `build/Ririku.app/Contents/MacOS/Ririku` from Terminal to see output.
- **Extension:** on the browser's extensions page, open **Inspect views: service worker** for `background.js`; content scripts log in the YouTube tab's DevTools console.
- **Native host:** its errors go to the browser's stderr. Launch the browser from Terminal (`/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome`) to see them.
- **Preferences:** `defaults read io.github.lanstheprodigy.ririku`. **Lyrics cache:** `~/Library/Caches/io.github.lanstheprodigy.ririku/Lyrics-v2`.
- **Without a browser:** turn on **Setup → Prototype → Local demo**.

Do not paste cookies, tokens, or personal browsing data into logs or issues.

## Verification

Run the checks that match your change before opening a pull request:

```sh
swift build
swift test
node --test Tests/Extension/*.test.cjs
bash scripts/build-app.sh
codesign --verify --deep --strict build/Ririku.app
/usr/bin/python3 scripts/check-localization.py   # translations complete, placeholders match
/usr/bin/python3 scripts/check-version.py        # one version in build script, manifest, code, changelog
/usr/bin/python3 scripts/check-docs.py           # documentation links, anchors, translation headers
for file in extension/*.js; do node --check "$file"; done
```

GitHub Actions runs the same checks on every push and pull request (`.github/workflows/ci.yml`) on a macOS runner, builds the bundle, verifies its signature and contents, and uploads a zip as a build artifact. `.github/workflows/release.yml` builds a tag into a **draft** release; see [releasing.md](releasing.md).

`swift test` runs the Swift Testing suites in `Tests/`:

| Target | Covers |
| --- | --- |
| `RirikuCoreTests` | LRC parsing, active line and offset, the Japanese display filter, snapshot validation, the position estimate, title normalization and candidate matching, bridge framing, and island motion |
| `RirikuTests` | Interface language resolution, `UIText`/`Localizer`, the browser catalogue and `BrowserSetup` outside an app bundle, the launch-at-login state, source selection, commands and acks, preferences, panel geometry, and lyric rows |

The tests use fixtures only: no network requests, no browser, and no access to a real browser profile (`BrowserSetup.home` can be redirected, and model tests use an in-memory `UserDefaults` and a temporary cache folder). The test binary is not an app bundle, so `LoginItem` reports `unavailable` and the tests never read or change your real login items. UI rendering, real browser integration, registering a login item, and audio timing are still verified by hand. Describe in your pull request what you ran and what you could not test.

### Manual smoke test

For Spotify desktop, enable **Setup → Music source → Connect Spotify desktop** in the built app, approve Automation, and test play/pause, previous/next, seek, automatic/manual source switching with a browser, track/artwork/lyric changes, quit/reopen Spotify, and denied permission followed by reconnect. Confirm the duration matches Spotify; no scripted live playback is part of unit tests. Test scripts only compile against the installed dictionary when Spotify is present. Repeat the same checks for Apple Music with **Connect Apple Music**, using a library song and an Apple Music streaming song, and confirm artwork appears and that a radio station is not shown as a song.

On both YouTube and YouTube Music:

1. Play → pause → seek forward and back → next track.
2. Open a second tab and start playback; with automatic source on, Ririku follows it. Turn automatic off and lock a tab in Setup.
3. Close the tab, refresh a tab, and quit/reopen Ririku; the connection recovers without restarting Chrome.
4. Check that the highlighted lyric line matches the audio, not just that text moves. Try a song without lyrics, captions (CC), an ad, and a live stream.
5. Switch the interface language and check Setup, the panel, the menu bar, and the extension popup.
6. Turn **Open Ririku at login** on in Setup, check that macOS lists Ririku under **System Settings → General → Login Items**, log out and back in, then turn it off again.
7. With a second Chromium browser installed, click **Register** again, load the extension there, and check that step 4 names that browser. Only one browser connects at a time.
