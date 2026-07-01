#!/bin/sh
# 02-configure-pmbootstrap.sh
# Initializes pmbootstrap for Raspberry Pi 5 + PocketTerm35 + Phosh
# Writes config directly (without interactive prompts)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> 02: pmbootstrap init – RPi5, PocketTerm35, Phosh"

PMBOOTSTRAP="$(command -v pmbootstrap || echo "$HOME/pmbootstrap/pmbootstrap.py")"
if [ ! -x "$PMBOOTSTRAP" ]; then
    echo "Error: pmbootstrap not found. Run 01-install-pmbootstrap.sh first."
    exit 1
fi

# Check if pmaports is already present
PMAPORTS_DIR="$HOME/.local/var/pmbootstrap/cache_git/pmaports"
if [ ! -d "$PMAPORTS_DIR/.git" ]; then
    echo "==> pmaports not found. Cloning (this may take a while)..."
    mkdir -p "$PMAPORTS_DIR"
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$PMAPORTS_DIR"
else
    echo "==> pmaports already present"
fi

echo "==> Writing pmbootstrap configuration..."

mkdir -p "$HOME/.config"
cat > "$HOME/.config/pmbootstrap_v3.cfg" << CFGEOF
[pmbootstrap]
boot_size = 512
build_pkgs_on_install = false
ccache_size = 5G
device = raspberry-pi5
extra_packages = none
extra_space = 0
hostname =
jobs = 8
kernel = rpi
keymap =
locale = en_US.UTF-8
ssh_key_glob = ~/.ssh/*.pub
ssh_keys = false
sudo_timer = false
systemd = default
timezone = GMT
ui = phosh
ui_extras = false
user = pmos
work = /home/admin/.local/var/pmbootstrap

[providers]

[mirrors]
alpine = http://dl-cdn.alpinelinux.org/alpine/
alpine_custom = none
pmaports = http://mirror.postmarketos.org/postmarketos/
pmaports_custom = none
systemd = http://mirror.postmarketos.org/postmarketos/extra-repos/systemd/
systemd_custom = none
CFGEOF

echo "==> Configuration written."
"$PMBOOTSTRAP" config device
"$PMBOOTSTRAP" config ui
"$PMBOOTSTRAP" config user

echo ""
echo "==> 02: Done"
echo "    Next: ./03-prepare-dtbos.sh"
