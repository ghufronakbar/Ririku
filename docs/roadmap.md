# Roadmap

This is the agreed plan for growing Ririku into a multipurpose notch app (decisions D-017 to D-024 in the [decision log](decisions.md#decisions)). Everything here is **planned, not implemented**, until the [changelog](../CHANGELOG.md) records that it shipped. The binding rules for these features are in [rules.md](rules.md#widgets-and-tools-r-wid).

## Stages

Each stage lands as one or more focused pull requests with tests, translations (R-DOC-1), and user guide updates once behavior changes (R-DOC-3). Target versions can move; the order should not.

| Stage | Work | Target |
| --- | --- | --- |
| 0 | Rules, decisions, and this roadmap | Done on 2026-10-05 |
| 1 | Refactor without behavior change: split `AppModel` and `main.swift` into app, music, panel, and Setup parts, and give Setup a sidebar with one page per area | Done on 2026-10-05 |
| 2 | General settings (D-022): display choice, hover and close delays, Dock and menu bar icons, haptic feedback, keyboard shortcut, tutorial, About | Done on 2026-10-05 |
| 3 | Tabs and widget framework, layout editor in Setup with a live preview, default layout, Music and System widgets | Done on 2026-10-05 |
| 4 | Local widgets: clock and date, Pomodoro, countdown, stopwatch, network speed, battery, notes, counter, days left, water, apps, shortcuts, bookmarks | Done on 2026-10-05 |
| 5 | Tray with AirDrop, then clipboard history | 0.5.0 |
| 6 | Calendar, camera mirror, Translate, then lyric translation | 0.6.0 |

## Panel layout

- The panel is a list of **tabs**. A tab is either a **page of widgets**, where each widget is small (one unit) or wide (two units) and the number of units follows the panel width, or a **tool** that fills the tab (Tray, Clipboard, Translate).
- **Default layout** (D-018): Home with Music (wide) and System, then Tray. Clipboard and Translate appear as tabs when turned on. Every other widget starts off. Until the Tray ships in stage 5, the default layout is Home alone.
- **Editing** happens in **Setup → Layout** with a live preview: turn widgets on or off, reorder by dragging, choose small or wide, add widget pages, hide tabs, and **Reset to default layout**. Settings stay out of the panel (R-UI-1).
- The **compact island** keeps showing music. When nothing is playing, it may show a live widget such as a running timer. Widget notices appear there for about 3 seconds and never open the panel (R-UI-3, R-UI-6).

## Planned widgets and tools

| Feature | Built with | macOS permission | Default |
| --- | --- | --- | --- |
| Music, with lyrics | Existing player and lyrics pipeline | None (Automation only for desktop players, as today) | On, Home |
| System: CPU, memory, disk | `host_statistics64`, `host_processor_info`, volume capacity keys | None | On, Home |
| Network speed | Interface byte counters from `getifaddrs` | None | Off |
| Battery | IOKit power sources | None | Off |
| Clock and date | Foundation | None | Off |
| Pomodoro, countdown, stopwatch | Scheduled end times instead of a ticking timer (R-WID-4) | None | Off |
| Notes, counter, days left, water | Local storage | None | Off |
| Apps | `NSWorkspace` | None | Off |
| Shortcuts | `/usr/bin/shortcuts` with an argument list (R-WID-9) | None | Off |
| Bookmarks | Opened in the default browser (R-WID-11) | None | Off |
| Tray with AirDrop | Drag and drop, file bookmarks, `NSSharingService` | None | On, Tray tab |
| Clipboard history | `NSPasteboard`, skipping concealed items (R-WID-6) | None expected on macOS 15; see the [open questions](decisions.md#open-questions) | Off |
| Calendar, read-only | EventKit | Calendars | Off |
| Camera mirror | AVFoundation, only while visible (R-WID-5) | Camera | Off |
| Translate | Translation framework, on device, macOS 15 and later (R-WID-10) | None | Off |

## Future plans

These are not scheduled and each needs its own decision first:

- **AI assistant:** needs a choice of provider, a network destination, and key handling (R-SCOPE-2, R-SEC-1).
- **Editing the layout directly in the panel**, in addition to Setup.

## Not planned

- A Web View or any embedded web browser (D-019).
- Weather, which needs an online service (R-SCOPE-2).
- Upgrade or premium pages, or any paywall (R-SCOPE-3).
- A logo in the notch (R-UI-5).
