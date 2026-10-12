# Navi Calendar

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) plugin that adds a
**desktop widget** and a **bar widget** for calendars stored as `.ics` (iCalendar) files.

It is a `composite` plugin: one manifest ships a background **daemon** (loads and parses the
feeds), a **bar widget** (date pill + month popout) and a **desktop widget** (month grid +
agenda). Both widgets share the parsed events through the plugin's global variables, so a
single daemon does all the work regardless of how many widgets are on screen.

## Features

- Local `.ics` files (`/path/to/calendar.ics`, `~/…`, `file://…`) and remote feeds
  (`https://…`, `http://…`, `webcal://…`).
- Multiple sources with per-source labels and per-source event marker colors.
- Bar pill shows the date (or the next event, or just an icon) and opens a month popout
  with an agenda for the selected day.
- Desktop widget: month grid + agenda, three layouts (Month + agenda / Month only /
  Agenda only).
- Month navigation, "today" button, event dots on days with events.
- Auto-refresh for remote feeds (configurable interval).

## Requirements

- DMS `>= 1.5.0`
- `curl` (for remote/`webcal://` feeds)

## Install

Copy this directory into your DMS plugins folder, then scan:

```sh
cp -r naviCalendar ~/.config/DankMaterialShell/plugins/
dms ipc plugin-scan scan
```

Then enable **Navi Calendar** in *Settings → Plugins*, add it to a DankBar section and/or
place the desktop widget from the desktop edit mode.

## Configure

In *Settings → Plugins → Navi Calendar*:

- **Sources** — click **Add .ics file…** to pick local calendars with the built-in file
  browser, or type a path (`/home/me/calendar.ics`) / URL (`https://…` or `webcal://…`)
  directly, optionally with a label.
- **Bar widget shows** — Date / Next event / Icon only.
- **Desktop widget layout** — Month + agenda / Month only / Agenda only.
- **Agenda days** — how far ahead the agenda lists.
- **First day of week**, **event markers**, **remote refresh interval**,
  **desktop background opacity**.

## Files

| File | Surface | Purpose |
|------|---------|---------|
| `plugin.json` | — | Manifest (composite: daemon + widget + desktop) |
| `CalendarDaemon.qml` | daemon | Loads and parses every source, publishes global vars |
| `IcsParser.js` | — | Minimal `.ics` parser and date helpers |
| `BarWidget.qml` | widget | Bar pill + month popout with agenda |
| `DesktopWidget.qml` | desktop | Month grid + agenda |
| `AgendaList.qml` | — | Shared agenda list |
| `Settings.qml` | — | Settings UI |

## Limitations

- **Recurring events (`RRULE`) are not expanded.** A recurring event is shown once, at its
  `DTSTART`, and the agenda marks it as "repeats". `EXDATE`/`RECURRENCE-ID` are ignored.
- `TZID` times are treated as local time (only the `Z`/UTC and floating forms are converted).
- No event creation/editing — this is a read-only reader for `.ics` sources.
- `VALARM` and `VTIMEZONE` blocks are ignored.

## License

MIT
