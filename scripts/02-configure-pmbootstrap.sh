#!/bin/sh
# 02-configure-pmbootstrap.sh
# Desktop-only Sway build; no mobile shell or telephony UI.
# Writes config directly (without interactive prompts)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> 02: pmbootstrap init – RPi4, PocketTerm35, desktop Sway"

PMBOOTSTRAP="$(command -v pmbootstrap || echo "$HOME/pmbootstrap/pmbootstrap.py")"
if [ ! -x "$PMBOOTSTRAP" ]; then
    echo "Error: pmbootstrap not found. Run 01-install-pmbootstrap.sh first."
    exit 1
fi

# Check if pmaports is already present
PMAPORTS_DIR="$HOME/.local/var/pmbootstrap-pocketterm35-desktop/cache_git/pmaports"
if [ ! -d "$PMAPORTS_DIR/.git" ]; then
    echo "==> pmaports not found. Cloning (this may take a while)..."
    mkdir -p "$PMAPORTS_DIR"
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$PMAPORTS_DIR"
else
    echo "==> pmaports already present"
fi

# Preserve prior host configuration once; never silently lose a working setup.
if [ -f "$HOME/.config/pmbootstrap_v3.cfg" ] && [ ! -e "$HOME/.config/pmbootstrap_v3.cfg.before-pocketterm35" ]; then
    cp -p "$HOME/.config/pmbootstrap_v3.cfg" "$HOME/.config/pmbootstrap_v3.cfg.before-pocketterm35"
fi
echo "==> Writing pmbootstrap configuration..."

mkdir -p "$HOME/.config"
cat > "$HOME/.config/pmbootstrap_v3.cfg" << CFGEOF
[pmbootstrap]
aports = $PMAPORTS_DIR
boot_size = 512
build_pkgs_on_install = false
ccache_size = 5G
device = raspberry-pi4
extra_packages = bash,upower,i2c-tools,evtest,libinput-tools,python3,py3-gobject3,gtk+3.0,brightnessctl,foot,font-dejavu,font-jetbrains-mono,font-hack,font-fira-mono-ttf,font-adobe-source-code-pro,font-inconsolata,font-liberation,font-noto,fontconfig,filezilla,qbittorrent,thunderbird,telegram-desktop,pcmanfm,elogind,sway,swaybg,swaylock,swayidle,waybar,wofi,mako,wvkbd-mobintl,xwayland,dbus,mesa-dri-gallium,mesa-utils,networkmanager-tui,pulseaudio-utils,bluez,util-linux,util-linux-misc,kmod,logrotate
extra_space = 0
hostname = pocketterm35
jobs = 8
kernel = stable
keymap = us
locale = en_US.UTF-8
ssh_key_glob = ~/.ssh/*.pub
ssh_keys = false
sudo_timer = false
service_manager = openrc
timezone = GMT
ui = sway
ui_extras = false
user = flylopi
work = $HOME/.local/var/pmbootstrap-pocketterm35-desktop

[providers]

[mirrors]
alpine = http://dl-cdn.alpinelinux.org/alpine/
alpine_custom = none
pmaports = http://mirror.postmarketos.org/postmarketos/
pmaports_custom = none
systemd = http://mirror.postmarketos.org/postmarketos/extra-repos/systemd/
systemd_custom = none
CFGEOF

# Direct configuration must initialize the work version just as `init` does.
# Read the installed pmbootstrap constant; never mark existing chroots migrated.
python3 - "$(dirname "$(readlink -f "$PMBOOTSTRAP")")" "$HOME/.local/var/pmbootstrap-pocketterm35-desktop" <<'PYINIT'
import pathlib
import sys
sys.path.insert(0, sys.argv[1])
import pmb.config
work = pathlib.Path(sys.argv[2])
work.mkdir(parents=True, exist_ok=True, mode=0o700)
version = work / 'version'
if not version.exists():
    if list(work.glob('chroot_*')) or (work / 'workdir.cfg').exists():
        raise SystemExit('Refusing to assign a work version to existing unversioned chroots')
    version.write_text(str(pmb.config.work_version) + '\n')
PYINIT

echo "==> Configuration written."
"$PMBOOTSTRAP" config device
"$PMBOOTSTRAP" config ui
"$PMBOOTSTRAP" config user

echo ""
echo "==> 02: Done"
echo "    Next: ./03-prepare-dtbos.sh"
