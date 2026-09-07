# Dependencies

Exact package names for building and running ZarisWM, per package manager.
This is a living document — as the WM or shell gains/drops a dependency,
this needs updating alongside it, and it doesn't cover every distro yet.

**Status**: Arch/pacman and Debian/apt are both verified below. Arch got
a full from-scratch `cmake` configure + build against exactly the listed
package set. Debian/apt's package names are confirmed against real apt
metadata (Devuan Excalibur, a Debian 13/trixie base) — every build-dep
name resolves to a real candidate — but hasn't had the same from-scratch
build attempt yet, so treat it as one notch below Arch's confidence
level. Fedora/dnf hasn't been started at all — see
[ROADMAP.md](ROADMAP.md)'s dependency-list beta blocker.

## Build dependencies

What `cmake` needs to configure and build the `zaris` binary itself —
see `CMakeLists.txt`'s `pkg_check_modules` call, plus `xcb`/`xcb-shape`,
which it links directly without a pkg-config check for either.

| Needed for | pkg-config module(s) | Arch/pacman | Debian/apt |
|---|---|---|---|
| C++17 compiler | — | `gcc` | `g++` (or just `build-essential`, which pulls it in) |
| Build system | — | `cmake` | `cmake` |
| `pkg-config` itself | — | `pkgconf` | `pkg-config` |
| glib | `glib-2.0` | `glib2` | `libglib2.0-dev` |
| Core XCB + RandR/Xinerama/Shape | `xcb`, `xcb-randr`, `xcb-xinerama`, `xcb-shape` | `libxcb` (one package covers all four) | `libxcb1-dev`, `libxcb-randr0-dev`, `libxcb-xinerama0-dev`, `libxcb-shape0-dev` (Debian splits these into separate packages) |
| XCB utility helpers | `xcb-util` | `xcb-util` | `libxcb-util-dev` |
| EWMH/ICCCM window-manager helpers | `xcb-ewmh`, `xcb-icccm` | `xcb-util-wm` (one package covers both) | `libxcb-ewmh-dev`, `libxcb-icccm4-dev` (Debian splits these too) |
| Keysym helpers | `xcb-keysyms` | `xcb-util-keysyms` | `libxcb-keysyms1-dev` |
| Cursor helpers | `xcb-cursor` | `xcb-util-cursor` | `libxcb-cursor-dev` |

```sh
# Arch — verified by an actual clean configure + build against exactly this set
sudo pacman -S --needed gcc cmake pkgconf glib2 libxcb xcb-util xcb-util-wm xcb-util-keysyms xcb-util-cursor

# Debian/apt — names verified against real apt metadata, build not yet attempted end to end
sudo apt-get install build-essential cmake pkg-config git \
  libglib2.0-dev libxcb1-dev libxcb-randr0-dev libxcb-ewmh-dev \
  libxcb-xinerama0-dev libxcb-cursor-dev libxcb-keysyms1-dev \
  libxcb-icccm4-dev libxcb-util-dev libxcb-shape0-dev
```

The general pattern: where Arch bundles several XCB extensions/helpers
into one package (`libxcb`, `xcb-util-wm`), Debian ships one `-dev`
package per pkg-config module. Worth remembering for anything new added
later — a single new Arch dependency may turn into several Debian ones.

## Shell runtime dependencies

What `shell/` (the Quickshell bar/launcher/OSD/lock, see
[shell/README.md](shell/README.md)) needs at runtime, beyond the WM
itself.

| Purpose | Arch/pacman | Debian/apt |
|---|---|---|
| The shell runtime itself | `quickshell` (official, `extra`) | **Not packaged at all.** Install via Nix: `nix profile install nixpkgs#quickshell` (see `contrib/devuan-bootstrap.sh`) |
| Audio stack + `wpctl` for the volume OSD | `pipewire`, `pipewire-pulse`, `wireplumber` | `pipewire`, `pipewire-pulse`, `wireplumber` |
| Notification daemon | `dunst` | `dunst` |
| Power menu's picker | `rofi` | `rofi` |
| Screenshots (+ clipboard copy) | `maim`, `xclip` | `maim`, `xclip` |
| Idle-based screen lock timer | `xautolock` — **official on Artix's `galaxy` repo; looks AUR-only on stock Arch**, worth re-checking against archlinux.org before relying on it there | **Not packaged under any name** — confirmed via `apt-cache search`, nothing matches. Debian's closest equivalent is `xss-lock`, which drives locking off logind DBus signals instead of an idle timer — a real mechanism swap, not a drop-in replacement, and not yet resolved (still open) |
| Screen locker | `i3lock` | `i3lock` |
| Default background color | `xorg-xsetroot` (or `xwallpaper` for an actual image) | `x11-xserver-utils` (provides `xsetroot`), or `xwallpaper` |
| Bar icon glyphs (Nerd Font) | `ttf-jetbrains-mono-nerd` (official, `extra`) | **No Nerd Font-patched package** — Debian only has the unpatched `fonts-jetbrains-mono`. Install the patched version via Nix instead |
| Notification icon theme | `papirus-icon-theme` | `papirus-icon-theme` |
| `loginctl` for the power menu (non-systemd only) | `elogind` (not needed at all on a systemd-default Arch install) | `elogind`, `libpam-elogind` |

The Arch-side data is what's actually installed and running on this
project's own Artix reference machine. The Debian-side data is apt
metadata confirmed real on a live Devuan Excalibur VM, not guessed.

**Screen locker: resolved.** Originally `betterlockscreen`/`i3lock-color`
on Arch, neither of which exist in Debian's repos at all (and are
AUR-only even on Arch). Swapped to plain `i3lock` instead, confirmed as
an official package on Arch, Debian, *and* Fedora alike (the only locker
that clears all three) — one dependency, uniform across every target
distro, no per-distro branching needed. The tradeoff: `i3lock` has no
built-in blur/theming, so the previous blurred-wallpaper look is gone
for now. `zaris.conf`'s idle-lock comment block has the note for anyone
who wants to add that back later — it'd need a small vendored script
(screenshot via `scrot`/`import`, blur via `imagemagick`, then hand off
to `i3lock`), since no distro packages that combination as one thing.

**Idle-lock timer: still open.** `xautolock` isn't packaged for Debian
under any name — this is a genuine remaining gap, separate from the
locker itself, and still needs a decision (build from source, or switch
to `xss-lock`'s different DBus-signal-driven mechanism) before Debian/
Devuan's idle-lock feature can be called done.
