# Pomodoro

A small pomodoro timer that lives in the macOS menu bar. Click the icon, get a
Control Center style panel with the timer, start/pause, skip and reset. That's it.

- Icon in the menu bar, time next to it while a session is running
- 25 / 5 / 15 by default, long break every 4 sessions, all adjustable
- Five built-in ringtones (bell, bright bell, phone ring, pulsing alarm, chime)
- Optional auto-start of the next session and launch at login
- Liquid Glass, no Dock icon, no windows, nothing else

Needs macOS 26 or later.

## Install

Grab `Pomodoro.dmg` from the [latest release](../../releases/latest), open it and
drag Pomodoro to Applications.

The app isn't notarized (no paid developer account), so the first launch gets
blocked. Go to System Settings → Privacy & Security, scroll down and hit
**Open Anyway**. One time only.

## Build it yourself

```sh
./build.sh
open Pomodoro.app
```

That builds a release binary with SwiftPM and wraps it in an app bundle.
`./build.sh dmg` also packs it into a dmg. Tagging a commit `v1.2.3` and pushing
it does the same on GitHub and attaches the dmg to a release.

## Layout

```
Sources/
  App.swift        status item, floating panel, all the UI
  Pomodoro.swift   timer state, phases, settings
  Sounds.swift     ringtones, synthesized with AVAudioEngine
```

Settings are stored in `UserDefaults` under `se.emil.pomodoro`.

## Notes

The panel is a plain transparent `NSPanel` rather than `MenuBarExtra`, because
`MenuBarExtra` always draws a glass background behind the content and I wanted
each tile to float on its own.

The ringtones are the same ones from the web pomodoro in
[kumpan-intra](../kumpan-intra), ported from Web Audio to a rendered PCM buffer.

## License

MIT
