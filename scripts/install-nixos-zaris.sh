#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# NixOS + XLibre + Zaris VM Installer
# Target: NixOS 26.05 / UEFI / Btrfs
#
# WARNING:
# This script ERASES the selected disk.
# ============================================================

USERNAME="mike"
HOSTNAME="nixos-zaris"
TIMEZONE="America/New_York"
DISK="/dev/vda"

echo
echo "============================================================"
echo "        NixOS + XLibre + Zaris VM Installer"
echo "============================================================"
echo
echo "Target disk: $DISK"
echo "Hostname:    $HOSTNAME"
echo "Username:    $USERNAME"
echo

echo "Current disks:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
echo

read -rp "Type ERASE to erase $DISK: " CONFIRM

if [[ "$CONFIRM" != "ERASE" ]]; then
    echo "Aborted."
    exit 1
fi

if [[ ! -b "$DISK" ]]; then
    echo "ERROR: $DISK does not exist."
    echo
    echo "Run:"
    echo "  lsblk"
    echo
    echo "Then edit DISK at the top of this script."
    exit 1
fi

echo
echo "Checking UEFI..."
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo "ERROR: The ISO does not appear to be booted in UEFI mode."
    echo "Enable UEFI in the VM firmware and boot the ISO again."
    exit 1
fi

echo
echo "Installing tools required by the installer..."
nix-shell -p btrfs-progs gptfdisk --run true

echo
echo "Unmounting anything currently mounted from target disk..."
umount -R /mnt 2>/dev/null || true

echo
echo "Wiping partition table..."
wipefs -a "$DISK"

echo
echo "Creating GPT partition table..."
parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1GiB \
    set 1 esp on \
    mkpart primary 1GiB 100%

EFI="${DISK}1"
ROOT="${DISK}2"

echo
echo "Formatting EFI partition..."
mkfs.fat -F 32 -n NIXOS_BOOT "$EFI"

echo
echo "Formatting Btrfs root..."
mkfs.btrfs -f -L NIXOS "$ROOT"

echo
echo "Creating Btrfs subvolumes..."

mount "$ROOT" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log

umount /mnt

echo
echo "Mounting Btrfs subvolumes..."

mount -o subvol=@,compress=zstd,noatime "$ROOT" /mnt

mkdir -p /mnt/home
mount -o subvol=@home,compress=zstd,noatime "$ROOT" /mnt/home

mkdir -p /mnt/nix
mount -o subvol=@nix,compress=zstd,noatime "$ROOT" /mnt/nix

mkdir -p /mnt/var/log
mount -o subvol=@log,compress=zstd,noatime "$ROOT" /mnt/var/log

mkdir -p /mnt/boot
mount "$EFI" /mnt/boot

echo
echo "Mounted filesystem:"
findmnt /mnt
echo

echo "Generating hardware configuration..."
nixos-generate-config --root /mnt

CONFIG="/mnt/etc/nixos/configuration.nix"

echo
echo "Writing NixOS configuration..."

cat > "$CONFIG" <<'NIXCONFIG'
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ----------------------------------------------------------
  # Boot
  # ----------------------------------------------------------

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ----------------------------------------------------------
  # Networking
  # ----------------------------------------------------------

  networking.hostName = "nixos-zaris";
  networking.networkmanager.enable = true;

  # ----------------------------------------------------------
  # Locale / timezone
  # ----------------------------------------------------------

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb.layout = "us";

  # ----------------------------------------------------------
  # X11 / LightDM / Qtile
  # ----------------------------------------------------------

  services.xserver = {
    enable = true;

    displayManager.lightdm.enable = true;

    windowManager.qtile.enable = true;
  };

  # ----------------------------------------------------------
  # Graphics
  # ----------------------------------------------------------

  hardware.graphics.enable = true;

  # ----------------------------------------------------------
  # User
  # ----------------------------------------------------------

  users.users.mike = {
    isNormalUser = true;
    description = "Mike";

    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];

    initialPassword = "nixos";
  };

  # Disposable VM convenience.
  # We will remove this after the VM is working.
  security.sudo.wheelNeedsPassword = false;

  # ----------------------------------------------------------
  # Flakes
  # ----------------------------------------------------------

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # ----------------------------------------------------------
  # Useful tools
  # ----------------------------------------------------------

  environment.systemPackages = with pkgs; [
    git
    vim
    nano
    curl
    wget

    pciutils
    usbutils

    mesa-demos

    xorg.xrandr
    xorg.xprop
    xorg.xwininfo
    xorg.xdpyinfo
  ];

  # ----------------------------------------------------------
  # State version
  # ----------------------------------------------------------

  system.stateVersion = "26.05";
}
NIXCONFIG

echo
echo "Creating initial flake..."

cat > /mnt/etc/nixos/flake.nix <<'FLAKE'
{
  description = "NixOS XLibre Zaris test system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    xlibre-overlay.url =
      "git+https://codeberg.org/takagemacoed/xlibre-overlay";
  };

  outputs = { self, nixpkgs, xlibre-overlay, ... }:
    {
      nixosConfigurations.nixos-zaris =
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./configuration.nix

            {
              nixpkgs.overlays = [
                xlibre-overlay.overlays.default
              ];
            }
          ];
        };
    };
}
FLAKE

echo
echo "============================================================"
echo "Configuration created."
echo "============================================================"
echo

echo "Testing Nix configuration evaluation..."

cd /mnt/etc/nixos

nix --extra-experimental-features "nix-command flakes" \
    flake lock

echo
echo "Flake locked successfully."
echo

echo "Installing NixOS..."
echo

nixos-install \
    --flake /mnt/etc/nixos#nixos-zaris \
    --no-root-passwd

echo
echo "============================================================"
echo "NixOS installation completed."
echo "============================================================"
echo
echo "IMPORTANT:"
echo
echo "The initial user password is:"
echo
echo "    nixos"
echo
echo "After reboot, log in as:"
echo
echo "    $USERNAME"
echo
echo "Then change the password."
echo
echo "The next stage will be installing/testing:"
echo
echo "    NixOS"
echo "      ↓"
echo "    XLibre"
echo "      ↓"
echo "    LightDM"
echo "      ↓"
echo "    Qtile"
echo "      ↓"
echo "    Zaris"
echo
echo "Remove the ISO and reboot."
echo

read -rp "Press ENTER to reboot..."

reboot
