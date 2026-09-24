# Pomodoro

A tomato timer that lives in your menu bar and stays out of your way.

Click the icon, hit start, do the thing. When the timer runs out you get a
little chime and a break. Four rounds later you get a longer one. That's the
whole app.

- Sits in the menu bar, shows the countdown while it's running
- 25 / 5 / 15 out of the box, tweak them if you like
- Five ringtones, from a polite chime to an alarm clock you'll want to punch
- Auto-start the next round, launch at login, or neither
- Liquid Glass, no Dock icon, no windows, no account, no nonsense

Needs macOS 26 or later.

## Install

Grab `Pomodoro.dmg` from the [latest release](../../releases/latest) and drag
it into Applications.

First launch will get blocked, because I'm not paying Apple $99 a year to
notarize a tomato. System Settings → Privacy & Security → **Open Anyway**.
Once, and never again.

## Build it yourself

```sh
./build.sh
open Pomodoro.app
```

`./build.sh dmg` also packs it into a dmg. Pushing a `v*` tag does the same on
GitHub and hangs the dmg on a release.

## Poking around

```
Sources/
  App.swift        menu bar item, the floating panel, all the UI
  Pomodoro.swift   timer, phases, settings
  Sounds.swift     the ringtones, synthesized on the fly
```

The panel is a plain transparent `NSPanel` instead of SwiftUI's `MenuBarExtra`,
which insists on drawing a glass slab behind everything. I wanted the tiles to
float like Control Center, so I made my own.

The sounds aren't audio files, they're a handful of sine and triangle waves with
envelopes, rendered into a buffer on first play. The whole app is a few hundred
lines.

## License

MIT. Do what you want with it.
