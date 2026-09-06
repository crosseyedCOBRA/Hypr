# ZarisWM

ZarisWM is a dynamic tiling window manager for Xorg/X11, written in XCB with
modern C++.

It started as a fork of [vaxerski/Hypr](https://github.com/vaxerski/Hypr) —
vaxry's dormant, pre-[Hyprland](https://github.com/vaxerski/Hyprland) X11
window manager — and has since diverged with its own bar/launcher shell,
window management fixes, and features. See [ROADMAP.md](ROADMAP.md) for the
full, ongoing list of what's done, what's planned, and what's still
undecided.

## Features

- Dynamic tiling (dwindle + master layouts)
- Multi-monitor support, with a global workspace pool
- An external EWMH-compatible bar/launcher built with [Quickshell](https://quickshell.outfoxxed.me/) — workspaces, clock, system tray, CPU/GPU temperature, network status, volume, a "stay awake" toggle, and a configurable "hidden tray" for modules you don't want always visible
- A GUI settings window for the bar's module configuration
- Idle-based screen lock (`xautolock` + `betterlockscreen`)
- Window rules, including `class:`/`role:`/`title:` matching and per-app fullscreen/floating/centering behavior
- Parabolic animations, rounded corners and borders
- Config reloaded instantly on save

## Building

```
git clone <this repo> zaris
cd zaris
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

The built binary is `build/zaris`.

## Configuring

Place your config at `~/.config/zaris/zaris.conf` — see
[example/zaris.conf](example/zaris.conf) for a documented starting point.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
