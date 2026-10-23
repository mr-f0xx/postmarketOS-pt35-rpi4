#!/bin/sh
# File-only installer, reusable for a mounted image or pmbootstrap rootfs.
# Run as root. Does not execute target binaries or assume host architecture.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ROOT=${1:?Usage: install-rootfs.sh /path/to/target-rootfs [sway]}
SESSION=${2:-sway}
case "$SESSION" in sway) ;; *) echo 'Unknown session' >&2; exit 2 ;; esac
[ "$(id -u)" = 0 ] || { echo 'Root required' >&2; exit 1; }
[ "$ROOT" != / ] && [ -f "$ROOT/etc/passwd" ] || { echo 'Refusing unsafe target root' >&2; exit 1; }
[ -e "$ROOT/etc/init.d/tinydm" ] || { echo 'This integration requires the postmarketOS tinydm display manager' >&2; exit 1; }
# Backup only once, preserving known-working settings across repeat installs.
backup() {
    if [ -f "$1" ] && [ ! -e "$1.before-pocketterm35" ]; then cp -p "$1" "$1.before-pocketterm35"; fi
}
put() {
    mode=$1 src=$2 dest="$ROOT/$3"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    install -m "$mode" "$PROJECT_DIR/$src" "$dest"
}
for name in pocketterm35-session pocketterm35-lock pocketterm35-idle pocketterm35-osk pocketterm35-bar pocketterm35-waybar pocketterm35-windows pocketterm35-power pocketterm35-zram pocketterm35-theme pocketterm35-launcher pocketterm35-notifications pocketterm35-fonts pocketterm35-apps pocketterm35-overclock; do
    put 755 "tools/$name" "usr/local/bin/$name"
done
put 755 tools/pocketterm35-controls.py usr/local/bin/pocketterm35-controls
put 755 scripts/pocketterm35-check.sh usr/local/bin/pocketterm35-check
put 755 tools/pocketterm35-report usr/local/bin/pocketterm35-report
put 644 assets/themes/palettes.json usr/share/pocketterm35/themes/palettes.json
put 644 configs/mako/config usr/share/pocketterm35/themes/mako-base.conf
put 644 assets/wallpapers/manifest.json usr/share/pocketterm35/wallpapers/manifest.json
for image in "$PROJECT_DIR"/assets/wallpapers/*.png; do
    put 644 "assets/wallpapers/$(basename "$image")" "usr/share/pocketterm35/wallpapers/$(basename "$image")"
done
put 644 configs/sway/config etc/sway/pocketterm35.conf
put 644 configs/waybar/config.json etc/xdg/waybar/pt35-base.json
put 644 configs/waybar/style.css etc/xdg/waybar/pt35-style.css
put 644 configs/mako/config etc/xdg/mako/config
put 644 configs/foot/foot.ini etc/xdg/foot/foot.ini
put 644 configs/dconf/00-pocketterm35 etc/dconf/db/local.d/00-pocketterm35
put 644 configs/applications/pocketterm35-controls.desktop usr/share/applications/pocketterm35-controls.desktop
put 644 configs/wayland-sessions/pocketterm35.desktop usr/share/wayland-sessions/pocketterm35.desktop
put 644 configs/logrotate/pocketterm35 etc/logrotate.d/pocketterm35
mkdir -p "$ROOT/etc/dconf/profile"
# Don't destroy an existing multi-database dconf profile.
profile="$ROOT/etc/dconf/profile/user"
backup "$profile"
[ -f "$profile" ] || printf 'user-db:user\n' > "$profile"
grep -qx 'system-db:local' "$profile" || printf 'system-db:local\n' >> "$profile"
for service in pocketterm35-power pocketterm35-zram; do
    put 755 "configs/openrc/$service" "etc/init.d/$service"
    mkdir -p "$ROOT/etc/runlevels/default"
    ln -sf "/etc/init.d/$service" "$ROOT/etc/runlevels/default/$service"
done
mkdir -p "$ROOT/etc/conf.d"
[ -f "$ROOT/etc/conf.d/pocketterm35-power" ] || printf 'profile="balanced"\n' > "$ROOT/etc/conf.d/pocketterm35-power"
# Disable cellular services in the actual image, after package installation.
for service in modemmanager ofono mmsd mmsd-tng; do
    for level in boot default; do
        link="$ROOT/etc/runlevels/$level/$service"
        if [ -L "$link" ]; then rm "$link"; fi
    done
done
# Save the previous display session for an explicit recovery path.
mkdir -p "$ROOT/var/lib/tinydm"
current="$ROOT/var/lib/tinydm/default-session.desktop"
if [ -L "$current" ] && [ ! -L "$current.before-pocketterm35" ]; then
    cp -P "$current" "$current.before-pocketterm35"
fi
ln -sf /usr/share/wayland-sessions/pocketterm35.desktop "$current"
echo "Installed desktop-only PocketTerm35 defaults; selected Sway"
