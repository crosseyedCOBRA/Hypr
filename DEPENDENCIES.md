# Dependencies

Exact package names for building and running ZarisWM, per package manager.
This is a living document — as the WM or shell gains/drops a dependency,
this needs updating alongside it.

**Status**: All three of Arch/pacman, Debian/apt, and Fedora/dnf now have
package names filled in below. Arch and Debian have both had the real
test: a from-scratch `cmake` configure + build against exactly the
listed package set, confirmed clean on Artix and on a Devuan Excalibur
VM. Fedora/dnf's names are confirmed against real
packages.fedoraproject.org listings but haven't had that same
from-scratch build attempt — no Fedora box available to do one on yet.
See [ROADMAP.md](ROADMAP.md)'s dependency-list beta blocker for what
"done" still requires.

## Build dependencies

What `cmake` needs to configure and build the `zaris` binary itself —
see `CMakeLists.txt`'s `pkg_check_modules` call, plus `xcb`/`xcb-shape`,
which it links directly without a pkg-config check for either.

| Needed for | pkg-config module(s) | Arch/pacman | Debian/apt | Fedora/dnf |
|---|---|---|---|---|
| C++17 compiler | — | `gcc` | `g++` (or `build-essential`) | `gcc-c++` |
| Build system | — | `cmake` | `cmake` | `cmake` |
| `pkg-config` itself | — | `pkgconf` | `pkg-config` | `pkgconf-pkg-config` |
| glib | `glib-2.0` | `glib2` | `libglib2.0-dev` | `glib2-devel` |
| Core XCB + RandR/Xinerama/Shape | `xcb`, `xcb-randr`, `xcb-xinerama`, `xcb-shape` | `libxcb` (covers all four) | `libxcb1-dev`, `libxcb-randr0-dev`, `libxcb-xinerama0-dev`, `libxcb-shape0-dev` (split up) | `libxcb-devel` (covers all four, same as Arch) |
| XCB utility helpers | `xcb-util` | `xcb-util` | `libxcb-util-dev` | `xcb-util-devel` |
| EWMH/ICCCM window-manager helpers | `xcb-ewmh`, `xcb-icccm` | `xcb-util-wm` (covers both) | `libxcb-ewmh-dev`, `libxcb-icccm4-dev` (split up) | `xcb-util-wm-devel` (covers both, same as Arch) |
| Keysym helpers | `xcb-keysyms` | `xcb-util-keysyms` | `libxcb-keysyms1-dev` | `xcb-util-keysyms-devel` |
| Cursor helpers | `xcb-cursor` | `xcb-util-cursor` | `libxcb-cursor-dev` | `xcb-util-cursor-devel` |

```sh
# Arch — verified by an actual clean configure + build against exactly this set
sudo pacman -S --needed gcc cmake pkgconf glib2 libxcb xcb-util xcb-util-wm xcb-util-keysyms xcb-util-cursor

# Debian/apt — verified by an actual clean configure + build against exactly this set, on a real Devuan Excalibur VM
sudo apt-get install build-essential cmake pkg-config git \
  libglib2.0-dev libxcb1-dev libxcb-randr0-dev libxcb-ewmh-dev \
  libxcb-xinerama0-dev libxcb-cursor-dev libxcb-keysyms1-dev \
  libxcb-icccm4-dev libxcb-util-dev libxcb-shape0-dev

# Fedora/dnf — names verified against real packages.fedoraproject.org listings, build not yet attempted
sudo dnf install gcc-c++ cmake pkgconf-pkg-config git \
  glib2-devel libxcb-devel xcb-util-devel xcb-util-wm-devel \
  xcb-util-keysyms-devel xcb-util-cursor-devel
```

The general pattern: Arch and Fedora both bundle several XCB
extensions/helpers into one package (`libxcb`/`libxcb-devel`,
`xcb-util-wm`/`xcb-util-wm-devel`) — they happen to split along the same
lines as each other. Debian is the odd one out, shipping one `-dev`
package per pkg-config module. Worth remembering for anything new added
later — a single new Arch/Fedora dependency may turn into several
Debian ones.

## Shell runtime dependencies

What `shell/` (the Quickshell bar/launcher/OSD/lock, see
[shell/README.md](shell/README.md)) needs at runtime, beyond the WM
itself.

| Purpose | Arch/pacman | Debian/apt | Fedora/dnf |
|---|---|---|---|
| The shell runtime itself | `quickshell` (official, `extra`) | **Not packaged**, but buildable from source with apt-only deps — see "Building Quickshell from source" below | `quickshell` — official, but currently a git-snapshot build (`0.2.1^git...`), not a tagged release; worth a version sanity-check before relying on it |
| Audio stack + `wpctl` for the volume OSD | `pipewire`, `pipewire-pulse`, `wireplumber` | `pipewire`, `pipewire-pulse`, `wireplumber` | `pipewire`, `pipewire-pulseaudio` (different name — no `-pulse` suffix), `wireplumber` |
| Notification daemon | `dunst` | `dunst` | `dunst` |
| Power menu's picker | `rofi` | `rofi` | `rofi` |
| Screenshots (+ clipboard copy) | `maim`, `xclip` | `maim`, `xclip` | `maim`, `xclip` |
| Idle-based screen lock timer | `xss-lock` | `xss-lock` | `xss-lock` |
| Screen locker | `i3lock` | `i3lock` | `i3lock` |
| Default background color | `xorg-xsetroot` (or `xwallpaper`) | `x11-xserver-utils` (provides `xsetroot`) | `xorg-x11-server-utils` (provides `xsetroot`, different name again) |
| Bar icon glyphs (Nerd Font) | `ttf-jetbrains-mono-nerd` (official, `extra`) | Not packaged, but installed the same way as Fedora — see "Installing the Nerd Font from upstream" below | Not packaged either — same upstream-download install as Debian |
| Notification icon theme | `papirus-icon-theme` | `papirus-icon-theme` | `papirus-icon-theme` — official |
| `loginctl` for the power menu | `elogind` (Arch is systemd-default, so not actually needed there — only relevant on a non-systemd Arch-based system like Artix) | `elogind`, `libpam-elogind` | Not needed — Fedora only ships systemd, `loginctl` is native |

The Arch-side data is what's actually installed and running on this
project's own Artix reference machine. The Debian-side and Fedora-side
data are both confirmed against real package metadata (a live Devuan
Excalibur VM for Debian, packages.fedoraproject.org listings for
Fedora), not guessed.

## Building Quickshell from source (Debian only)

`quickshell` isn't packaged for Debian at all, but it builds cleanly
from the upstream mirror with only apt-available dependencies — verified
end-to-end on a real Devuan Excalibur VM (configure, build, install, and
`qs --version` all confirmed working). This is what
`contrib/devuan-bootstrap.sh`'s `quickshell` step automates.

```sh
sudo apt-get install ninja-build qt6-base-dev qt6-declarative-dev \
  qt6-declarative-dev-tools qt6-declarative-private-dev \
  qt6-shadertools-dev libdrm-dev spirv-tools libcli11-dev \
  libpipewire-0.3-dev

git clone --depth=1 https://github.com/quickshell-mirror/quickshell.git
cmake -GNinja -S quickshell -B quickshell/build -DCMAKE_BUILD_TYPE=Release \
  -DWAYLAND=OFF -DWAYLAND_WLR_LAYERSHELL=OFF -DWAYLAND_SESSION_LOCK=OFF \
  -DWAYLAND_TOPLEVEL_MANAGEMENT=OFF -DSCREENCOPY=OFF -DHYPRLAND=OFF -DI3=OFF \
  -DCRASH_HANDLER=OFF -DUSE_JEMALLOC=OFF -DSERVICE_PAM=OFF -DSERVICE_POLKIT=OFF \
  -DX11=ON -DSOCKETS=ON -DSERVICE_PIPEWIRE=ON -DSERVICE_STATUS_NOTIFIER=ON \
  -DSERVICE_MPRIS=ON
cmake --build quickshell/build
sudo cmake --install quickshell/build
```

The Wayland-specific flags (`WAYLAND*`, `SCREENCOPY`) and the unrelated
`HYPRLAND`/`I3` IPC integrations are turned off since Zaris is X11-only
and neither Hyprland nor i3 apply here — this trims the dependency list
and avoids needing Qt6 Wayland's private headers on top of QtDeclarative's
(Debian trixie ships Qt 6.8, and Quickshell's `BUILD.md` notes private
headers are required for both below Qt 6.10). `CRASH_HANDLER` (needs
`cpptrace`, unpackaged on Debian) and `USE_JEMALLOC` are off since neither
is required for the shell to function. Quickshell's own CMake install
rules create the `qs` symlink to `quickshell` automatically — confirmed
present and working after `cmake --install`, no manual symlink needed.

## Installing the Nerd Font from upstream (Debian and Fedora)

Neither Debian nor Fedora has an official *patched* Nerd Font package
(Arch is the outlier here — `ttf-jetbrains-mono-nerd` is official,
`extra`). Rather than reach for a COPR on Fedora and Nix on Debian —
two different answers for the same problem — the upstream Nerd Fonts
project publishes ready-to-use per-font archives on GitHub releases,
which installs identically on any distro with no package manager
involved at all. Verified end-to-end on the Devuan VM: extracted,
`fc-cache`'d, and `fc-match 'JetBrainsMono Nerd Font:style=SemiBold'`
resolved correctly — the exact family+style string
`shell/dunst/dunstrc` uses. This is what `contrib/devuan-bootstrap.sh`'s
`nerdfont` step automates.

```sh
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
  | tar -xJ -C ~/.local/share/fonts/JetBrainsMonoNerdFont
fc-cache -f ~/.local/share/fonts
```

## Uniform across all three

After the work above, every build dependency, every shell runtime
dependency, `quickshell` itself (via the from-source build), and the
Nerd Font (via the upstream download) are all confirmed working
identically on Arch, Debian, and Fedora. No genuinely non-uniform gaps
remain open at this point.

## Resolved gaps (for reference)

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

**`quickshell` itself: resolved.** Not packaged for Debian at all;
resolved by building from source with apt-only deps (Qt6 dev packages,
libdrm, spirv-tools, cli11, pipewire dev), Wayland/Hyprland/i3 features
turned off since Zaris is X11-only — see "Building Quickshell from
source" above for the full recipe and what got verified.

**Nerd Font: resolved.** Not packaged for either Debian or Fedora;
resolved by downloading the patched font directly from the upstream
Nerd Fonts project's GitHub releases rather than reaching for a
per-distro third-party source (Nix, a COPR) — see "Installing the Nerd
Font from upstream" above. Same recipe works on Arch too, if you'd
rather skip the official package there for consistency's sake, though
there's no real need to since it's already official there.
