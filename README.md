# Ririku

**Synced lyrics and music controls in your Mac's notch.**

English · [Bahasa Indonesia](README.id.md) · [日本語](README.ja.md)

Ririku (リリク, from "lyric") is a free, open-source macOS app that shows what is playing in YouTube or YouTube Music in Google Chrome right under the notch, with play/pause, skip, seek, and line-by-line synced lyrics. It is a native SwiftUI/AppKit app with a small companion Chrome extension, no account, and no telemetry.

> **Status:** early prototype (v0.3.0). No release has been published yet, so for now Ririku must be [built from source](docs/development/README.md). Apple Music and Spotify are planned but not supported.

## Features

- **Notch panel:** artwork, a decorative spectrum, and up to three lyric lines in a compact island; hover or click to expand for track info, a seek bar, and controls.
- **Synced lyrics:** found automatically from [LRCLIB](https://lrclib.net) by title, artist, and duration, and cached on your Mac. You can also use the video's captions, pick another lyrics version, adjust timing per song, or import your own `.lrc` file.
- **Japanese-friendly lyrics:** when a lyrics file has Japanese and romaji on the same timestamp, Ririku can show only the Japanese line.
- **Follows the active player:** switches to the Chrome tab that starts playing, or lock one tab manually.
- **Customizable:** island width, number of lyric lines, accent color, animations, and Reduce Motion support.
- **Interface languages:** English, Bahasa Indonesia, and 日本語, following your macOS language or chosen in Setup.

## Requirements

- macOS 14 Sonoma or later. Developed on Apple silicon; Intel Macs are untested.
- A MacBook with a notch is recommended. Other displays use the main screen, which is not fully tested.
- Google Chrome with YouTube (`www.youtube.com`) or YouTube Music (`music.youtube.com`). Other Chromium browsers are not supported yet.

## Install

Ririku is free and is not notarized by Apple (notarization requires a paid developer account), so macOS asks you to confirm the first launch. The [user guide](docs/user-guide.md#install) covers every step in detail.

1. **Get the app.** Download `Ririku.zip` from [Releases](https://github.com/ghufronakbar/ririku/releases) once available, unzip it, and move **Ririku.app** to your **Applications** folder. Until the first release, [build it from source](docs/development/README.md).
2. **Allow it to open.** Open Ririku. If macOS blocks it, go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
3. **Connect Chrome.** Ririku opens **Setup**. In **Chrome connection**, follow the four steps: **Register**, **Show in Finder**, load that folder from `chrome://extensions` with **Developer mode** and **Load unpacked**, then refresh your YouTube tab.

Play a song in Chrome and hover over the notch.

## Using Ririku

- **Open the panel:** hover over the notch, click the island, or choose **Open music panel** from the waveform icon in the menu bar. Press Esc to close it.
- **Setup:** click the gear in the expanded panel or choose **Setup…** from the menu bar icon.
- **Lyrics out of sync?** In **Setup → Lyrics**, adjust the offset for this song, or use **Search and choose a lyrics version** to pick a version whose duration matches the player.
- **No music handy?** Turn on **Setup → Prototype → Local demo** to try the panel without Chrome.

See the [user guide](docs/user-guide.md) for all settings, troubleshooting, updating, and uninstalling.

## Privacy

Ririku has no account and sends no analytics. When automatic lyrics search is on, the song title, artist, and duration are sent to LRCLIB. Thumbnails are loaded from YouTube/Google image servers. The extension only runs on YouTube and YouTube Music and reads the player on the page; it does not read cookies or browsing history. See [Privacy](docs/user-guide.md#privacy) in the user guide.

Lyrics come from LRCLIB; their availability and timing are not guaranteed. Ririku keeps lyrics only in a local cache and does not download audio or video.

## Contributing

Bug reports, translations, and code are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and the [developer documentation](docs/development/README.md). Please report security issues privately as described in [SECURITY.md](SECURITY.md). Release notes are in [CHANGELOG.md](CHANGELOG.md).

## Contact

Maintained by **lanstheprodigy** — GitHub [@ghufronakbar](https://github.com/ghufronakbar), X [@lansProdigy](https://x.com/lansProdigy), Instagram [@lanstheprodigy](https://instagram.com/lanstheprodigy).

Use [issues](https://github.com/ghufronakbar/ririku/issues) for bugs and ideas, and [SECURITY.md](SECURITY.md) for security reports.

## License

[MIT](LICENSE) © 2026 lanstheprodigy.

Ririku is not affiliated with or endorsed by Apple, Google, YouTube, or LRCLIB. Product names are trademarks of their respective owners.
