#!/usr/bin/env bash
#
# devuan-bootstrap.sh — take a fresh Devuan *server* install (the minimal,
# no-desktop ISO — no X, no display manager, often no sudo yet) all the way
# to a working ZarisWM session: build deps, ZarisWM itself and its
# Quickshell-based shell, XLibre (in place of stock Xorg), the XanMod
# kernel, the Nix package manager, and Flatpak/Flathub.
#
# Target: Devuan Excalibur (6.x, Debian 13/trixie base) on sysvinit. Run as
# a normal user, NOT as root — steps that need root use sudo themselves.
#
# The Devuan server ISO's installer only adds your user to the `sudo`
# group if you left the root password blank during install. If you set a
# root password instead, `sudo` won't even be installed yet — this script
# can't fix that from a non-root account, so as root, first run:
#   apt-get install -y sudo && usermod -aG sudo <your-username>
# then log out and back in before running this script.
#
# Usage:
#   ./devuan-bootstrap.sh [step ...]
# With no arguments, runs every step in order. Pass one or more step names
# (see STEPS below) to run only those, e.g.:
#   ./devuan-bootstrap.sh xlibre nix flatpak
#
# XLibre is a young, fast-moving Xorg fork; the packaged .deb has had
# reported input-device issues on Devuan specifically (missing seatd/libseat
# wiring for non-systemd seat management). This script installs seatd and
# the .deb package as the fast path, and prints a fallback source-build
# recipe if keyboard/mouse input doesn't work after switching to it.
#
# There's no display manager here — the `shell` step wires up ~/.xinitrc
# so `startx` launches ZarisWM directly.

set -euo pipefail

ZARIS_REPO_URL="${ZARIS_REPO_URL:-https://github.com/crosseyedcobra/zaris.git}"
ZARIS_SRC_DIR="${ZARIS_SRC_DIR:-$HOME/src/zaris}"

STEPS=(apt-base xanmod zaris-deps zaris-build shell seatd xlibre elogind nix flatpak)

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m==> WARNING:\033[0m %s\n' "$*" >&2; }

preflight() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "Run this as your normal user (it calls sudo itself), not as root." >&2
        exit 1
    fi
    if ! command -v sudo >/dev/null 2>&1 || ! sudo -v 2>/dev/null; then
        cat >&2 <<EOF
sudo isn't set up for $USER yet — this is common straight after a Devuan
server install if you set a root password during setup. As root, run:
    apt-get install -y sudo && usermod -aG sudo $USER
then log out and back in and re-run this script.
EOF
        exit 1
    fi
}

step_apt-base() {
    log "Updating base system"
    sudo apt-get update
    sudo apt-get -y upgrade
    sudo apt-get -y install curl ca-certificates gnupg git build-essential
}

step_xanmod() {
    log "Installing the XanMod kernel"
    # The kernel package itself doesn't care about init system — this is
    # exactly as init-agnostic on Devuan as on any other Debian derivative.
    # The one gotcha: XanMod's repo only publishes suites named after
    # Debian codenames, but Devuan's own /etc/os-release codename
    # (excalibur) differs from the Debian base it tracks (trixie), so we
    # hardcode the Debian codename rather than auto-detecting it.
    local debian_codename="trixie"

    wget -qO - https://dl.xanmod.org/archive.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org ${debian_codename} main" \
        | sudo tee /etc/apt/sources.list.d/xanmod-release.list >/dev/null

    local level
    level="$(curl -fsSL https://dl.xanmod.org/check_x86-64_psabi.sh | bash 2>/dev/null | grep -o 'x86-64-v[0-9]' | tail -1)"
    local pkg="linux-xanmod-x64v3"
    case "$level" in
        x86-64-v1) pkg="linux-xanmod-x64v1" ;;
        x86-64-v2) pkg="linux-xanmod-x64v2" ;;
        x86-64-v3|x86-64-v4) pkg="linux-xanmod-x64v3" ;;
        *) warn "Couldn't detect CPU psABI level, defaulting to $pkg — check https://dl.xanmod.org/check_x86-64_psabi.sh yourself if unsure." ;;
    esac

    sudo apt-get update
    sudo apt-get -y install "$pkg"

    cat <<EOF

Installed $pkg. This does NOT reboot you into it — your current kernel
stays the GRUB default until you choose the XanMod entry (or reboot and
pick it from the GRUB menu) and confirm it works before making it
default. XanMod isn't signed for UEFI Secure Boot, so disable that in
firmware setup first if it's on.
EOF
}

step_zaris-deps() {
    log "Installing ZarisWM build dependencies"
    # Matches CMakeLists.txt's pkg-config deps: glib-2.0, xcb-randr,
    # xcb-ewmh, xcb-xinerama, xcb-cursor, xcb-keysyms, xcb-icccm, xcb-util
    # (plus xcb-shape, linked directly but not pkg-config-checked).
    sudo apt-get -y install \
        cmake pkg-config g++ \
        libglib2.0-dev \
        libxcb1-dev \
        libxcb-randr0-dev \
        libxcb-ewmh-dev \
        libxcb-xinerama0-dev \
        libxcb-cursor-dev \
        libxcb-keysyms1-dev \
        libxcb-icccm4-dev \
        libxcb-util-dev \
        libxcb-shape0-dev
}

step_zaris-build() {
    log "Cloning and building ZarisWM"
    if [ -d "$ZARIS_SRC_DIR/.git" ]; then
        git -C "$ZARIS_SRC_DIR" pull --ff-only
    else
        git clone "$ZARIS_REPO_URL" "$ZARIS_SRC_DIR"
    fi
    cmake -S "$ZARIS_SRC_DIR" -B "$ZARIS_SRC_DIR/build" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$ZARIS_SRC_DIR/build" -j"$(nproc)"
    # shell/zaris/start-zaris.sh execs this exact path, so match it rather
    # than a system-wide /usr/local/bin install.
    install -Dm755 "$ZARIS_SRC_DIR/build/zaris" "$HOME/.local/bin/zaris"
    echo "Installed to ~/.local/bin/zaris."
}

step_shell() {
    log "Installing the Quickshell-based bar/launcher/OSD shell"
    if [ ! -d "$ZARIS_SRC_DIR/shell" ]; then
        echo "No $ZARIS_SRC_DIR/shell — run the 'zaris-build' step first." >&2
        exit 1
    fi
    # Runtime deps available in Debian/Devuan repos (shell/README.md's
    # full list). Not here: quickshell itself (see the `nix` step) and a
    # Nerd Font (also easiest via Nix, e.g.
    # `nix profile install nixpkgs#nerd-fonts.jetbrains-mono`).
    #
    # zaris.conf's idle-lock now runs on xss-lock + i3lock rather than
    # this project's earlier xautolock + betterlockscreen — neither of
    # those old choices were packaged for Debian at all, xss-lock and
    # i3lock both are.
    sudo apt-get -y install \
        pipewire pipewire-pulse wireplumber \
        dunst rofi maim xclip i3lock xss-lock \
        x11-xserver-utils papirus-icon-theme

    for d in quickshell zaris dunst rofi; do
        mkdir -p "$HOME/.config/$d"
        cp -r "$ZARIS_SRC_DIR/shell/$d/." "$HOME/.config/$d/"
    done
    chmod +x "$HOME/.config/zaris/"*.sh

    cat > "$HOME/.xinitrc" <<'EOF'
#!/bin/sh
exec "$HOME/.config/zaris/start-zaris.sh"
EOF
    chmod +x "$HOME/.xinitrc"

    cat <<EOF

Shell config copied to ~/.config/{quickshell,zaris,dunst,rofi}, and
~/.xinitrc wired up to launch it — 'startx' will now bring up ZarisWM.

Still worth doing by hand before first launch (see shell/README.md):
- Add your own xrandr call in ~/.config/zaris/start-zaris.sh if you have
  more than one monitor.
- Fix the hardcoded hwmon sensor labels in
  ~/.config/quickshell/Bar.qml for your own CPU/GPU
  (grep . /sys/class/hwmon/hwmon*/temp*_label).
- Swap the bar's logo (~/.config/quickshell/assets/artix.svg).
- Install quickshell itself and a Nerd Font — see the 'nix' step.
EOF
}

step_seatd() {
    log "Installing seatd (non-systemd seat/device management, needed by XLibre)"
    sudo apt-get -y install seatd
    sudo adduser "$USER" _seat 2>/dev/null || sudo adduser "$USER" seat 2>/dev/null || true
    # seatd ships a sysvinit script on Devuan; enable + start it.
    if [ -x /etc/init.d/seatd ]; then
        sudo update-rc.d seatd defaults
        sudo service seatd start || true
    else
        warn "No /etc/init.d/seatd script found — start/enable seatd manually for your init."
    fi
}

step_xlibre() {
    log "Adding the XLibre (X11Libre) apt repository"
    # Third-party repo maintained by NexusSfan for Debian/Devuan; see
    # https://github.com/xlibre-debian/debian and
    # https://github.com/X11Libre/packaging/discussions/5
    curl -fsSL https://mrchicken.nexussfan.cz/publickey.asc \
        | gpg --dearmor | sudo tee /usr/share/keyrings/NexusSfan.pgp >/dev/null
    sudo chmod a+r /usr/share/keyrings/NexusSfan.pgp

    local components="stable"
    if grep -qi 'testing\|forky' /etc/os-release 2>/dev/null; then
        components="testing"
    fi

    sudo tee /etc/apt/sources.list.d/xlibre-debian.sources >/dev/null <<EOF
Types: deb
URIs: https://xlibre-debian.github.io/debian/
Suites: main
Components: ${components}
Signed-By: /usr/share/keyrings/NexusSfan.pgp
EOF

    sudo apt-get update
    sudo apt-get -y install xlibre xlibre-archive-keyring

    cat <<'EOF'

XLibre installed. On Devuan/sysvinit specifically, there have been reports
of the packaged build not receiving keyboard/mouse/trackpad input (it needs
seatd-based, not systemd-logind-based, seat management — this script
already installed and enabled seatd for you). If input doesn't work after
switching your session to XLibre, rebuild it from source against seatd:

    sudo apt-get build-dep xserver-xorg-core
    sudo apt-get -y install libseat-dev meson ninja-build
    git clone --depth=1 https://github.com/X11Libre/xserver.git ~/src/xlibre-xserver
    meson setup --prefix=/usr ~/src/xlibre-xserver/build ~/src/xlibre-xserver \
        -Dsystemd_logind=false -Dseatd_libseat=true
    ninja -C ~/src/xlibre-xserver/build
    sudo ninja -C ~/src/xlibre-xserver/build install

Track the upstream issue for current status:
https://github.com/X11Libre/packaging/discussions/62
EOF
}

step_elogind() {
    log "Installing elogind (loginctl, for ZarisWM shell's power menu)"
    # shell/README.md: the power menu's suspend/reboot/shutdown actions
    # need `loginctl`, which is systemd-logind on systemd or elogind here.
    sudo apt-get -y install elogind libpam-elogind
}

step_nix() {
    log "Installing Nix (single-user, no daemon/init-script required)"
    if command -v nix >/dev/null 2>&1; then
        echo "nix already installed, skipping."
        return
    fi
    # Multi-user Nix's installer only wires up systemd for the daemon; a
    # single-user install needs no daemon or init script at all, which is
    # the simplest correct option on sysvinit. See:
    # https://nix.dev/install-nix.html
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
    cat <<'EOF'

Nix installed in single-user mode. Open a new shell (or `source
~/.nix-profile/etc/profile.d/nix.sh`) to pick it up.

Quickshell (the shell/bar this project uses) is packaged directly in
nixpkgs, which sidesteps needing a rolling distro just for a fresh Qt6/
Quickshell build:

    nix profile install nixpkgs#quickshell

Want multi-user Nix instead (build sandboxing, shared daemon across
users)? The installer supports it, but on sysvinit you have to hand-write
the nix-daemon init script yourself — the installer only automates that
for systemd. See the "Nix on non-systemd" thread if you want to go that
route: https://discourse.nixos.org/t/install-nix-daemon-on-non-systemd-init/7911
EOF
}

step_flatpak() {
    log "Installing Flatpak + Flathub"
    sudo apt-get -y install flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

main() {
    preflight
    local steps=("$@")
    if [ "${#steps[@]}" -eq 0 ]; then
        steps=("${STEPS[@]}")
    fi
    for s in "${steps[@]}"; do
        if ! printf '%s\n' "${STEPS[@]}" | grep -qx "$s"; then
            echo "Unknown step: $s (known: ${STEPS[*]})" >&2
            exit 1
        fi
        "step_$s"
    done
    log "Done. Steps run: ${steps[*]}"
}

main "$@"
