# Zaris shell

This is the reference desktop shell for ZarisWM: the Quickshell-based bar,
app launcher, notification daemon config, volume OSD, and the scripts/theme
files that tie them together. The WM itself has no built-in bar (removed in
favor of this external EWMH shell — see `ROADMAP.md`), so without this,
ZarisWM is a tiling window manager with no panel, launcher, or on-screen
feedback of any kind.

This is a working *default*, not a first-run wizard — see `ROADMAP.md`'s
backlog for the planned interactive first-run setup (choosing which bar
modules show, tray contents, whether to enable a dock, etc.) that will
eventually customize this rather than requiring hand-edits.

## What's here

| Directory              | Installs to             | What it is |
|-------------------------|--------------------------|------------|
| `quickshell/`           | `~/.config/quickshell/`  | The bar, launcher, OSD, settings window, and their shared state/config (QML + `modules.json`) |
| `zaris/`                | `~/.config/zaris/`       | `zaris.conf` (the WM config paired with this shell), the session launch script, and helper scripts (power menu, screenshot, volume OSD) |
| `dunst/`                | `~/.config/dunst/`       | Notification daemon config, themed to match the shell's palette |
| `rofi/`                 | `~/.config/rofi/`        | Theme used by the power menu's `rofi -dmenu` prompt |

## Install

1. Build and install the WM itself first (see the top-level `README.md`).
2. Copy each directory above to its target location, e.g.:
   ```sh
   cp -r shell/quickshell/. ~/.config/quickshell/
   cp -r shell/zaris/.      ~/.config/zaris/
   cp -r shell/dunst/.      ~/.config/dunst/
   cp -r shell/rofi/.       ~/.config/rofi/
   chmod +x ~/.config/zaris/*.sh
   ```
3. Point your display manager's session entry (or however you start X) at
   `~/.config/zaris/start-zaris.sh`.
4. **Edit for your own hardware before first launch:**
   - `zaris.conf`'s monitor-layout `exec-once` line (the `xrandr --output ...`
     one) and `start-zaris.sh`'s own `xrandr` call both hardcode this
     machine's specific outputs/rotations/positions (3 monitors, one
     portrait). Replace with your own — run `xrandr --query` to see your
     output names.
   - `HwmonSensor` usages in `Bar.qml` (CPU/GPU temp) hardcode sensor labels
     (`Tctl`, `edge`) specific to this machine's CPU/GPU. Check
     `grep . /sys/class/hwmon/hwmon*/temp*_label` on your own machine and
     adjust if different — the comments in `Bar.qml` mark exactly where.
   - The bar's logo (`assets/artix.svg`) is the Artix Linux logo, since
     that's what this reference machine runs — swap it for your own
     distro's icon or anything else you'd rather click to open the launcher.

## Runtime dependencies

Beyond what the WM itself needs to build:

- **quickshell** (`qs`) — the shell runtime itself
- **pipewire**, **pipewire-pulse**, **wireplumber** (includes `wpctl`) — audio + the volume OSD
- **dunst** — notification daemon
- **rofi** — the power menu's picker
- **maim** — screenshots (optionally **xclip** too, to also copy to clipboard)
- **xautolock** + **betterlockscreen** (wraps `i3lock-color`) — idle-based screen lock
- **xwallpaper** — sets the wallpaper in the example `exec-once` line (swap for whatever you prefer)
- A **Nerd Font** (JetBrainsMono Nerd Font in the reference config) — the bar's icons are glyphs from it, and it's also set as dunst's font
- An icon theme (Papirus-Dark in the reference `dunstrc`) — for notification icons
- `loginctl` (systemd-logind, or **elogind** on a non-systemd system) — the power menu's suspend/reboot/shutdown actions

## Known machine-specific bits

Nothing here that's flagged above should stop this from running elsewhere,
but it has only ever run on one machine (3 monitors, AMD CPU+GPU, Artix
Linux/OpenRC) — see the `[Beta blocker]` items in `ROADMAP.md` for what's
still unverified on different hardware/distros.
