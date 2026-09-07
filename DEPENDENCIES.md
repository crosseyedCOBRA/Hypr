# Dependencies

Exact package names for building and running ZarisWM, per package manager.
This is a living document — as the WM or shell gains/drops a dependency,
this needs updating alongside it, and it doesn't cover every distro yet.

**Status**: Arch/pacman is verified below (confirmed against a real
install, including an actual from-scratch `cmake` configure + build).
Debian/apt and Fedora/dnf are not done yet — see
[ROADMAP.md](ROADMAP.md)'s dependency-list beta blocker.
`contrib/devuan-bootstrap.sh` has a working apt package list for the build
deps (verified against real apt metadata on Devuan Excalibur/Debian 13),
which should fold in here once it's had a full from-scratch build
verification pass like Arch got below.

## Build dependencies

What `cmake` needs to configure and build the `zaris` binary itself —
see `CMakeLists.txt`'s `pkg_check_modules` call, plus `xcb`/`xcb-shape`,
which it links directly without a pkg-config check for either.

| Needed for                                   | pkg-config module(s)                          | Arch/pacman package |
|-----------------------------------------------|------------------------------------------------|----------------------|
| C++17 compiler                                | —                                              | `gcc`                |
| Build system                                  | —                                              | `cmake`              |
| `pkg-config` itself                           | —                                              | `pkgconf`            |
| glib                                          | `glib-2.0`                                    | `glib2`              |
| Core XCB + RandR/Xinerama/Shape extensions    | `xcb`, `xcb-randr`, `xcb-xinerama`, `xcb-shape` | `libxcb`           |
| XCB utility helpers                           | `xcb-util`                                    | `xcb-util`           |
| EWMH/ICCCM window-manager helpers             | `xcb-ewmh`, `xcb-icccm`                       | `xcb-util-wm`        |
| Keysym helpers                                | `xcb-keysyms`                                 | `xcb-util-keysyms`   |
| Cursor helpers                                | `xcb-cursor`                                  | `xcb-util-cursor`    |

One-liner:
```sh
sudo pacman -S --needed gcc cmake pkgconf glib2 libxcb xcb-util xcb-util-wm xcb-util-keysyms xcb-util-cursor
```

Verified by actually configuring and building clean against exactly this
package set (nothing more, nothing less) on Artix Linux.

## Shell runtime dependencies

What `shell/` (the Quickshell bar/launcher/OSD/lock, see
[shell/README.md](shell/README.md)) needs at runtime, beyond the WM
itself. Arch package name, and whether it's in the official repos or
needs the AUR:

| Purpose                                   | Arch/pacman package     | Official repo? |
|--------------------------------------------|--------------------------|----------------|
| The shell runtime itself                   | `quickshell`             | Yes (`extra`)  |
| Audio stack + `wpctl` for the volume OSD   | `pipewire`, `pipewire-pulse`, `wireplumber` | Yes |
| Notification daemon                        | `dunst`                  | Yes            |
| Power menu's picker                        | `rofi`                   | Yes            |
| Screenshots (+ clipboard copy)             | `maim`, `xclip`          | Yes            |
| Idle-based screen lock timer               | `xautolock`              | **Artix only** — official in Artix's `galaxy` repo; looks AUR-only on stock Arch currently, worth re-checking against archlinux.org before relying on it there |
| Screen locker (wraps `i3lock-color`)       | `betterlockscreen`, `i3lock-color` | **No — AUR on both Arch and Artix** |
| Default background color                   | `xorg-xsetroot` (or `xwallpaper` for an actual image) | Yes |
| Bar icon glyphs                            | `ttf-jetbrains-mono-nerd` | Yes (`extra`) |
| Notification icon theme                    | `papirus-icon-theme`     | Yes            |
| `loginctl` for the power menu (non-systemd only) | `elogind`          | Yes (not needed at all on a systemd-default Arch install — `loginctl` already exists via systemd itself) |

All of the above (including the two AUR packages) are what's actually
installed and running on this project's own Artix reference machine.
