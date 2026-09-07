#!/usr/bin/env bash
#
# devuan-bootstrap.sh — provision a fresh Devuan base/server install into a
# ZarisWM dev box: build deps, ZarisWM itself, XLibre (in place of stock
# Xorg), the Nix package manager, and Flatpak/Flathub.
#
# Target: Devuan Excalibur (6.x, Debian 13/trixie base) on sysvinit. Run as
# a normal sudo-capable user, NOT as root — steps that need root use sudo
# themselves.
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

set -euo pipefail

ZARIS_REPO_URL="${ZARIS_REPO_URL:-https://github.com/crosseyedcobra/zaris.git}"
ZARIS_SRC_DIR="${ZARIS_SRC_DIR:-$HOME/src/zaris}"

STEPS=(apt-base zaris-deps zaris-build seatd xlibre elogind nix flatpak)

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m==> WARNING:\033[0m %s\n' "$*" >&2; }

require_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "Run this as your normal user (it calls sudo itself), not as root." >&2
        exit 1
    fi
}

step_apt-base() {
    log "Updating base system"
    sudo apt-get update
    sudo apt-get -y upgrade
    sudo apt-get -y install curl ca-certificates gnupg git build-essential
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
    sudo install -Dm755 "$ZARIS_SRC_DIR/build/zaris" /usr/local/bin/zaris
    echo "Installed to /usr/local/bin/zaris. Shell (bar/launcher) is a"
    echo "separate step — see $ZARIS_SRC_DIR/shell/README.md."
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
    require_not_root
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
