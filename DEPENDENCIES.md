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
| Idle-based screen lock timer | `xss-lock` | `xss-lock` |
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

**Idle-lock timer: resolved.** Originally `xautolock`, which isn't
packaged for Debian under any name (confirmed via `apt-cache search`) and
looks AUR-only on stock Arch too (only official via Artix's own `galaxy`
repo). Swapped to `xss-lock`, confirmed official on Arch, Debian, *and*
Fedora — same uniformity win as the locker swap above. Real mechanism
difference worth knowing: `xss-lock` has no `-time` flag of its own, it
fires off the X screensaver extension's own activation event instead, so
the idle timeout now lives in the X server's screensaver timer (`xset q`)
rather than a dedicated option — verified end-to-end in a Xephyr sandbox
that `xss-lock -- i3lock` correctly spawns `i3lock` on that event.
`xss-lock` also listens for logind's Lock signal (elogind reimplements
this, already a shell dependency for the power menu's `loginctl` calls),
so a suspend/lid event or manual `loginctl lock-session` locks too, not
just idle timeout — a capability `xautolock` never had. One knock-on
simplification: the "stay awake" toggle's `xset s off` already fully
suppresses screensaver activation (and therefore `xss-lock`, which can't
fire without that event) on its own, so the separate `xautolock -enable`/
`-disable` IPC call this project's earlier setup needed is gone —
confirmed via `xset q` showing `timeout: 0` after `s off`, though the
actual auto-fire-vs-suppressed timing comparison didn't reproduce
cleanly under Xephyr (nested X servers are known to be unreliable about
real idle-timer counting), so that specific piece rests on X11's
well-established core-protocol semantics for `timeout: 0` rather than a
clean sandboxed reproduction.
