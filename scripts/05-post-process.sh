#!/bin/sh
# Mount only for copying files; run target commands through pmbootstrap/QEMU,
# never a raw aarch64 chroot on an x86 build host.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PMBOOTSTRAP=$(command -v pmbootstrap || printf '%s' "$HOME/pmbootstrap/pmbootstrap.py")
IMAGE=${1:-"$PROJECT_DIR/images/postmarketOS-latest.img"}
OVERLAY="$PROJECT_DIR/dtbos/waveshare-35dpi-5b.dtbo"
[ -f "$IMAGE" ] && [ -f "$OVERLAY" ] || { echo 'Image or touch overlay missing; run steps 03 and 04.' >&2; exit 1; }
[ "$("$PMBOOTSTRAP" config device)" = raspberry-pi4 ] || { echo 'Pi 4 device required' >&2; exit 1; }
# Step 04 already created the image: do not rebuild it and discard edits here.
"$PMBOOTSTRAP" shutdown
BOOT_MNT=$(mktemp -d)
ROOT_MNT=$(mktemp -d)
LOOP_DEV=''
cleanup() {
    sudo umount "$BOOT_MNT" 2>/dev/null || :
    sudo umount "$ROOT_MNT" 2>/dev/null || :
    if [ -n "$LOOP_DEV" ]; then sudo losetup -d "$LOOP_DEV"; LOOP_DEV=''; fi
    rmdir "$BOOT_MNT" "$ROOT_MNT"
}
trap cleanup EXIT
trap 'exit 1' INT TERM
LOOP_DEV=$(sudo losetup -fP --show "$IMAGE")
sudo mount "${LOOP_DEV}p1" "$BOOT_MNT"
sudo mount "${LOOP_DEV}p2" "$ROOT_MNT"
# Refuse to configure an unexpected image.
grep -q '^flylopi:' "$ROOT_MNT/etc/passwd"
[ -f "$BOOT_MNT/config.txt" ]
# One-time boot backups for recovery; never overwrite a previous backup.
for file in config.txt cmdline.txt usercfg.txt; do
    if [ -f "$BOOT_MNT/$file" ] && [ ! -e "$BOOT_MNT/$file.before-pocketterm35" ]; then
        sudo cp -p "$BOOT_MNT/$file" "$BOOT_MNT/$file.before-pocketterm35"
    fi
done
# Preserve kernel, initramfs and firmware settings supplied by device package.
if ! grep -Eq '^[[:space:]]*include[[:space:]]+usercfg.txt' "$BOOT_MNT/config.txt"; then
    printf '\n[all]\ninclude usercfg.txt\n' | sudo tee -a "$BOOT_MNT/config.txt" >/dev/null
fi
for file in "$PROJECT_DIR"/configs/usercfg.txt*; do sudo cp "$file" "$BOOT_MNT/"; done
# Preserve an existing opt-in choice when post-processing the same image again.
if [ ! -e "$BOOT_MNT/pocketterm35-overclock.txt" ]; then
    sudo cp "$PROJECT_DIR/configs/pocketterm35-overclock.txt" "$BOOT_MNT/"
fi
sudo mkdir -p "$BOOT_MNT/overlays"
sudo cp "$OVERLAY" "$BOOT_MNT/overlays/"
# KMS uses the kernel video argument, not legacy framebuffer/hdmi_cvt settings.
CMDLINE="$BOOT_MNT/cmdline.txt"
[ -f "$CMDLINE" ] || { echo 'Missing cmdline.txt; cannot safely force display mode' >&2; exit 1; }
sudo sed -i 's/ *video=HDMI-A-1:[^ ]*//g' "$CMDLINE"
sudo sed -i '1s/$/ video=HDMI-A-1:640x480@60D/' "$CMDLINE"
# Save known boot configuration before applying changes (first invocation only).
# Rootfs integration is file-only and doesn't need an ARM chroot on this host.
sudo sh "$PROJECT_DIR/scripts/install-rootfs.sh" "$ROOT_MNT" "${PT35_SESSION:-sway}"
# OpenRC compiles defaults at boot, before the display manager starts.
sudo mkdir -p "$ROOT_MNT/etc/init.d" "$ROOT_MNT/etc/runlevels/boot"
sudo tee "$ROOT_MNT/etc/init.d/pocketterm35-defaults" >/dev/null <<'RC'
#!/sbin/openrc-run
description="Compile PocketTerm35 desktop defaults"
depend() {
    need localmount
    before tinydm display-manager
}
start() {
    /usr/bin/dconf update
}
RC
sudo chmod 755 "$ROOT_MNT/etc/init.d/pocketterm35-defaults"
sudo ln -sf /etc/init.d/pocketterm35-defaults "$ROOT_MNT/etc/runlevels/boot/pocketterm35-defaults"
sync
cleanup
trap - EXIT
echo "Configured session: ${PT35_SESSION:-sway} (desktop-only)."
echo 'Login: flylopi / 0807. Test hardware with pocketterm35-check.'
# Build provenance beside the image, not inside Git.
META="$IMAGE.build.txt"
{
    date -u '+Built: %Y-%m-%dT%H:%M:%SZ'
    git -C "$PROJECT_DIR" rev-parse HEAD
    git -C "$PROJECT_DIR" status --porcelain
    "$PMBOOTSTRAP" --version
    for source in "$HOME/pmbootstrap" "$HOME/.local/var/pmbootstrap-pocketterm35-desktop/cache_git/pmaports"; do
        if [ -d "$source/.git" ]; then
            printf 'Upstream source: %s\n' "$source"
            git -C "$source" rev-parse HEAD
        fi
    done
    printf 'Session: %s\nDevice: raspberry-pi4\n' "${PT35_SESSION:-sway}"
} > "$META"
sha256sum "$IMAGE" > "$IMAGE.sha256"
# Hash actual source files too: uncommitted/untracked configuration is not
# represented by the repository revision alone.
(cd "$PROJECT_DIR"; find configs tools scripts assets -type f ! -path '*/__pycache__/*' -exec sha256sum {} \;) > "$IMAGE.sources.sha256"
