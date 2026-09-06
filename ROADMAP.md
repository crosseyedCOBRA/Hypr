# Roadmap

Tracking what's done, what's planned, and what's still undecided for this fork.

## Done / working

- Dynamic tiling (dwindle + master) — inherited from upstream Hypr, unchanged
- Multi-monitor support — verified end-to-end (bar on every screen, correct per-monitor workarea reservation)
- Workspaces — global pool model; switching pulls a workspace to the focused monitor
- Built-in status bar removed in favor of an external EWMH shell (Quickshell)
- Quickshell rofi-style app launcher (usage-sorted results, icons)
- Quickshell bar (workspaces, clock, system tray, CPU/GPU temp, network status, volume)
- Audio (pipewire / pipewire-pulse / wireplumber) autostart on session launch
- Window rules extended with `title:` matching (upstream Hypr only had `class:` / `role:`)
- Fullscreen window rule for games — turned out to already be fully implemented upstream (`windowrule=fullscreen,class:...`), just undocumented; verified live and added an example to `example/hypr.conf`
- Bug fixes along the way: missing `xcb-util` build dependency, dock/workarea reservation race at map time, an EWMH `_NET_WORKAREA` infinite-loop freeze, a RandR screen-change notification feedback loop, and a broken session launcher that was silently running a stale system-wide binary instead of the real one

## Backlog — discussed, not started

- **True live drag-and-drop retiling.** Other windows should visibly reshuffle in real time while a window is being dragged over them, not just snap into place on release. This is genuinely new work — even Hyprland doesn't fully do this today.
- **Bundled compositor.** Blur, shadows, and real anti-aliased rounded corners via XComposite/XDamage + GLX/EGL, likely adapting picom's (MIT-licensed) blur/rounded-corner shader code. (Animations and basic X-Shape-based rounded corners already work today without a compositor — this is about blur/shadows specifically, plus a visual upgrade to rounding.) This is the single biggest remaining piece of work and isn't sequenced or scoped yet.
- **GUI settings app.** A graphical tool for configuring the WM so users aren't limited to hand-editing the config file. Deliberately deferred until just before release.
- **Bar visual fixes.** Icons, layout, and general polish pass on the Quickshell bar.
- **Animations fix.** Something's currently off with Hypr's native window/workspace animations; needs investigation.
- **Launcher positioning.** The launcher floats correctly now, but isn't landing in the right place on screen (should be centered).

## Open decisions

- **Final project name.** Leading candidate is **Xobra** (X11 + the "Cobra" handle) — checked clean against GitHub, npm, PyPI, and crates.io — but this hasn't been locked in yet.
