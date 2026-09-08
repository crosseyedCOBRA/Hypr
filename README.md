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
- Idle-based screen lock (`xss-lock` + `i3lock`)
- Window rules, including `class:`/`role:`/`title:` matching and per-app fullscreen/floating/centering behavior
- Parabolic animations, rounded corners and borders
- Config reloaded instantly on save

## Building

See [DEPENDENCIES.md](DEPENDENCIES.md) for exact build-dependency package
names (Arch/pacman verified; other package managers still in progress).

```
git clone <this repo> zaris
cd zaris
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

The built binary is `build/zaris`.

The WM binary alone has no built-in bar or launcher — see below.

## Configuring

Place your config at `~/.config/zaris/zaris.conf` — see
[example/zaris.conf](example/zaris.conf) for a documented starting point.

## Shell (bar, launcher, notifications, OSD)

The bar/launcher/etc. mentioned above live in [shell/](shell/) as a
separate install step — see [shell/README.md](shell/README.md) for what's
in it and how to install it. Without it, the WM runs but has no panel,
launcher, or on-screen feedback of any kind.

## Third-party code

Some of `shell/quickshell/Style.qml`'s design-token scale (font sizes,
radii, margins, animation durations) is adapted from
[noctalia-dev/noctalia](https://github.com/noctalia-dev/noctalia)'s own
`Commons/Style.qml`, as it existed at the MIT-licensed
[v4.7.7](https://github.com/noctalia-dev/noctalia/tree/v4.7.7) release (the
project has since been rewritten in C++ under a different architecture) —
stripped of its dynamic per-user scale multipliers and bar-density/position
sizing logic, which don't apply to Zaris's simpler, fixed-layout bar. See
[ROADMAP.md](ROADMAP.md) for what else, if anything, gets adapted the same
way going forward.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
