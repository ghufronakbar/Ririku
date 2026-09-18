# Ririku user guide

English · [Bahasa Indonesia](user-guide.id.md) · [日本語](user-guide.ja.md)

This guide is for everyone who wants to use Ririku, no programming needed. It describes Ririku v0.3.1. Button names are shown as they appear in the English interface.

- [Before you start](#before-you-start)
- [Install](#install)
- [Using the panel](#using-the-panel)
- [Setup](#setup)
- [Getting better lyrics](#getting-better-lyrics)
- [Updating](#updating)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Privacy](#privacy)
- [Known limitations](#known-limitations)

## Before you start

You need:

- A Mac with **macOS 14 Sonoma or later**. Ririku is developed on Apple silicon; Intel Macs are untested.
- Ideally a MacBook with a **notch**. On other displays the panel appears at the top of the main screen, which is not fully tested.
- A **Chromium browser** — Chrome, Brave, Edge, Vivaldi, Opera, Chromium, or Arc — playing music on **YouTube** or **YouTube Music**. Chrome is the one Ririku is tested with; the others use the same extension but are still unverified. Safari, Firefox, Apple Music, and Spotify are not supported.

## Install

### 1. Get Ririku

Download `Ririku.zip` from the [Releases page](https://github.com/ghufronakbar/Ririku/releases) and double-click it to unzip. No release has been published yet; until then, Ririku can only be [built from source](development/README.md).

Move **Ririku.app** into your **Applications** folder **before opening it**. If you open it straight from Downloads, macOS runs it from a temporary location and Ririku cannot connect to your browser.

### 2. Open Ririku for the first time

Ririku is free and not notarized by Apple, because notarization requires a paid Apple developer account. macOS therefore blocks the first launch. The exact wording differs between macOS versions.

**macOS 15 Sequoia and later**

1. Double-click **Ririku** in Applications. macOS says it could not verify the app. Click **Done** (do not move it to the Trash).
2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
3. Next to the message about Ririku being blocked, click **Open Anyway**, then confirm with your password or Touch ID and click **Open**.

**macOS 14 Sonoma**

1. In Applications, Control-click (or right-click) **Ririku** and choose **Open**.
2. Click **Open** in the dialog.

You only need to do this once per downloaded version.

> **Advanced:** if you trust the download, you can instead run `xattr -dr com.apple.quarantine /Applications/Ririku.app` in Terminal.

Ririku has no Dock icon. It lives in the menu bar as a **waveform** icon, and the **Setup** window opens on first launch.

### 3. Connect your browser

Ririku reads the YouTube player in your browser through a small companion extension. In **Setup → Browser connection**, follow the four steps once. Each step shows a green check mark when it is done.

1. **Register the browser connection** → click **Register**. Ririku lets every Chromium browser it finds on your Mac talk to this copy of the app, and names them under the step.
2. **Copy the extension folder** → click **Show in Finder**. Ririku copies the extension to `~/Library/Application Support/Ririku/Chrome Extension` and shows it in Finder.
3. **Load the extension in your browser** → click **Copy Address** (with several browsers installed, choose one from the menu), paste the address into that browser's address bar, and press Return. Then:
   - Turn on **Developer mode** (top-right corner).
   - Click **Load unpacked** and choose the **Chrome Extension** folder from step 2.
   - The browser shows these buttons in its own language.
4. **Check the connection** → refresh any YouTube or YouTube Music tab that was already open. This step turns green and shows the browser and the extension version.

Now play something in that browser and hover over the notch.

Keep **Developer mode** on; browsers need it for extensions that are not from their own store. The extension folder is named "Chrome Extension" in every browser, because it is the same extension everywhere.

## Using the panel

Artwork uses the current video's YouTube thumbnail, which may differ from the album cover shown in YouTube Music. This avoids retaining an earlier song's player-bar image.

- **Compact island:** by default the island is exactly the size of your Mac's notch, so it stays hidden behind the camera housing; make it wider in **Setup → Appearance** to see the artwork on the left and a decorative spectrum on the right. Lyric lines appear below the notch while music plays. The spectrum is only an animation and settles when playback is paused; it does not analyze audio.
- **Expand:** hover over the notch or click the island. You can also choose **Open music panel** from the waveform menu bar icon.
- **Controls:** title, artist, and source; the gear button opens **Setup**; a seek bar; and previous, play/pause, and next. Buttons the website does not offer are disabled. Live streams show **LIVE** and cannot be seeked.
- **Close:** move the pointer away or press **Esc**.
- **Paused:** the artwork and the spectrum stay, and the lyrics leave the island so it shrinks back to the notch. The expanded panel keeps showing them.
- **Ads:** while YouTube shows an ad, controls are disabled and lyrics pause.
- **No lyrics:** the island stays compact and briefly shows **Lyrics not found**. Details are in **Setup → Lyrics**.

Choose **Quit Ririku** from the menu bar icon to quit.

## Setup

Open Setup from the gear button in the expanded panel or **Setup…** in the menu bar icon. Changes apply immediately.

### Language

**Interface language:** **Follow system** (default), English, Bahasa Indonesia, or 日本語. Follow system uses the first of these languages in **System Settings → General → Language & Region**, otherwise English. Song titles, lyrics, captions, and messages from macOS or websites keep their original language.

### Browser connection

The four install steps above. Come back here after updating Ririku, installing another browser, or moving the app to another folder.

### Startup

**Open Ririku at login** (off by default): Ririku opens in the background after you log in, without a Dock icon or a window. macOS may ask you to allow it the first time; if Setup says it is waiting for approval, click **Open Login Items settings** and turn Ririku on there. The toggle is unavailable while Ririku runs from a temporary location, so move it to **Applications** first. You can also turn it off in **System Settings → General → Login Items**.

### Music source

- **Automatically follow the active player** (on by default): Ririku follows the browser tab that starts playing.
- **Active player:** turn automatic mode off to lock one tab. Ririku reconnects to the same tab after a page refresh.

### Appearance

- **Compact island width** and **Compact island height** both start at the size of your Mac's notch — the default, and the smallest the island can be — and can grow by up to 440 pt and 40 pt. Setup names your notch size (for example 179 × 32 pt). The artwork and the spectrum stay on the left and right edges, so they come out from behind the camera housing as you widen the island; around 240 pt they are fully visible.
- **Expanded island width** (360–720 pt, default 442), used when the panel is hovered or opened.
- **Reset to the notch size** restores all three.
- **Accent color:** Auto — from artwork, Peach, Lavender, or Neutral. Auto extracts a dominant color locally from the current thumbnail, brightens it for the black background, and falls back to Neutral while artwork is unavailable or grayscale. Colors are cached in memory and transition smoothly unless animations or Reduce Motion disable them. No audio analysis or additional network request is involved; your existing manual selection is preserved.
- **Smooth panel transitions:** turn off for instant resizing. macOS **Reduce Motion** also disables animations and the spectrum.
- **Show lyrics in the island** and **Lyric lines:** 1 (current), 2 (current + next), or 3 (previous + current + next). When a song has lines too long for the island, the current line uses two rows for the whole song, so the height does not change from line to line; the previous and next lines stay on one row and end with “…”. A narrow island therefore still shows the line you are reading in full — widen the island if you want more of the surrounding lines too.

### Lyrics

- **Prefer Japanese on shared timestamps** (on by default): see [Japanese lyrics](#japanese-lyrics).
- **Lyrics source:**
  - **Automatic · LRCLIB, then captions:** timed lyrics from LRCLIB; if none are found and the video's captions (CC) are on, the captions are shown.
  - **LRCLIB / LRC only:** never show captions.
  - **YouTube subtitles only:** only show the player's captions and do not contact LRCLIB.
- **Search LRCLIB automatically when the song changes** (on by default).
- **Back to automatic result:** removes your manual choice for this song and searches LRCLIB again.
- **Import LRC…:** use your own `.lrc` file (UTF-8, up to 1 MB) for the current song until Ririku quits.
- **Offset for this song** and **Earlier/Later by 0.1 s:** see [Fixing timing](#fixing-timing).
- **Search and choose a lyrics version:** see [Choosing another version](#choosing-another-version).

### Prototype

**Local demo (no audio)** shows a sample song so you can try the panel without a browser. Turn it off before using real music.

## Getting better lyrics

Automatic lookup follows song changes; Setup also refreshes the suggested title and artist. Temporary LRCLIB 502/503/504 errors get bounded retries, but a persistent service outage can still prevent lyrics. Synced lines slide upward when animations are enabled; Reduce Motion disables scrolling. YouTube Music uses the current song's visible clock rather than a cumulative media duration. After updating the extension, reload it and refresh existing YouTube tabs once.

Ririku looks up lyrics on [LRCLIB](https://lrclib.net), a free community database, using the song title, artist, and duration. It only accepts a result automatically when the title and artist match and the duration is within 3 seconds. Lyrics are not guaranteed for every song, and timing depends on the recording that was submitted.

### Fixing timing

If every line is early or late by the same amount, use **Offset for this song** in **Setup → Lyrics**. Positive values delay the lyrics; negative values show them earlier. The offset is saved per video, so it applies again the next time you play the song. It does not apply to captions.

### Choosing another version

If lyrics drift, belong to a different edit, or are not found, open **Search and choose a lyrics version**. Type a title, artist, or alternate title (for example the Japanese or English title) and click **Search**. Results are sorted by how close their duration is to the player. A difference over 3 seconds is marked **check version** and often means a different intro, live, or cover recording. Click **Use** to apply a result. Your choice lasts until Ririku quits.

### Captions

If YouTube provides captions, turn on **CC** in the player. Ririku can show them when timed lyrics are unavailable, or always with **YouTube subtitles only**. Subtitles burned into the video image cannot be read.

### Japanese lyrics

Some LRCLIB files contain Japanese lines followed by romaji lines with the same timestamp. With **Prefer Japanese on shared timestamps** on, Ririku hides the Latin-only line when a Japanese line shares its exact timestamp. Lines at other times and mixed-language lines are kept, and nothing is deleted from the file. Turn it off to see every line, for example in bilingual duets.

## Updating

1. Quit Ririku from the menu bar icon.
2. Replace **Ririku.app** in Applications with the new version, then open it. You may need **Open Anyway** again.
3. In **Setup → Browser connection**, if a step is no longer green, click **Show in Finder** to copy the new extension, then click the extension's **reload** button on the browser's extensions page and refresh YouTube tabs.

If you move Ririku to another folder, click **Register Again** in step 1.

## Troubleshooting

**The Register button is disabled or an orange warning appears.** Ririku is running from a temporary location. Quit it, move **Ririku.app** to Applications, and open it again.

**Step 4 says "Not connected".**
- Make sure Ririku is running (waveform icon in the menu bar) and the browser is open.
- On the browser's extensions page, check that **Developer mode** is on and **Ririku — Browser Bridge** is enabled.
- Refresh the YouTube or YouTube Music tab and start playback.
- Click the extension's icon in the browser to see its status; **Try connecting now** retries, and **Open app Setup** opens Ririku.
- Load only one copy of the extension. Remove duplicates on the extensions page.
- Only one browser profile can be connected at a time. With the extension loaded in two browsers, the first one to connect wins; quit the other browser to switch.

**The extension icon shows "!".** The extension cannot reach Ririku. Open Ririku and complete **Setup → Browser connection**.

**"Registered for another copy of Ririku".** The app was moved or another copy was registered. Click **Register Again**.

**The extension is outdated.** Click **Show in Finder** in step 2, then the extension's reload button on the browser's extensions page.

**Lyrics not found.** LRCLIB may not have the song, or the video title may not match the song name. Try [Choosing another version](#choosing-another-version), captions, or **Import LRC…**.

**Lyrics are shown as plain text without a highlighted line.** Only untimed lyrics were found. Try another version.

**Previous or Next is disabled.** The page does not offer that button, for example a single video without a playlist.

**"Another Ririku instance is already running".** Quit the other copy of Ririku.

**YouTube changed and something stopped working.** Ririku reads the YouTube page, which can change without notice. Please [open an issue](https://github.com/ghufronakbar/Ririku/issues).

## Uninstall

1. Quit Ririku from the menu bar icon.
2. On your browser's extensions page, remove **Ririku — Browser Bridge**.
3. Move **Ririku.app** to the Trash.
4. Optionally remove its data. In Finder choose **Go → Go to Folder…** and delete only these items:
   - `~/Library/Application Support/Ririku`
   - `io.github.lanstheprodigy.ririku.bridge.json` in the `NativeMessagingHosts` folder of each browser you registered, for example `~/Library/Application Support/Google/Chrome/NativeMessagingHosts`
   - `~/Library/Caches/io.github.lanstheprodigy.ririku`
   - `~/Library/Preferences/io.github.lanstheprodigy.ririku.plist` (or run `defaults delete io.github.lanstheprodigy.ririku` in Terminal)

## Privacy

- **No account, no analytics.** Ririku does not collect usage data.
- **LRCLIB:** when automatic search is on, the song title, artist, and duration are sent to `lrclib.net`. **Search** sends the text you type. **YouTube subtitles only** mode does not contact LRCLIB.
- **Artwork:** thumbnails are downloaded from YouTube/Google image servers.
- **Browser extension:** runs only on `www.youtube.com` and `music.youtube.com` and uses only the `nativeMessaging` permission. It reads the player state, title, artist, artwork address, and visible captions on the page, and sends them only to the Ririku app on your Mac. It does not read cookies, passwords, or browsing history.
- **Stored on your Mac:** found lyrics are cached for 30 days (up to 300 files) and "not found" results for 30 minutes in `~/Library/Caches/io.github.lanstheprodigy.ririku`. Settings and per-song offsets are stored in Ririku's preferences; offsets include the video IDs of songs you adjusted.

## Known limitations

- Only YouTube and YouTube Music in a Chromium browser, one browser at a time; Apple Music, Spotify, Safari, and Firefox are not supported yet.
- Only Chrome is verified. Brave, Edge, Vivaldi, Opera, Chromium, and Arc use the same extension and host, but have not been tested yet; Arc's folder in particular still needs confirmation.
- The extension is installed with **Load unpacked** and does not update itself.
- Not notarized by Apple, so the first launch needs confirmation.
- Lyrics availability and timing depend on LRCLIB.
- YouTube page changes can break detection until Ririku is updated.
