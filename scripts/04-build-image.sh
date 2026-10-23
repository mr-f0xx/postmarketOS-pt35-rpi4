#!/bin/sh
# 04-build-image.sh
# Builds the postmarketOS image for PocketTerm35 with desktop-only Sway
# Set PMB_SUDO for passwordless sudo (wrapper) or ensure
# the user can run sudo without a password.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IMAGE_NAME="postmarketOS-pocketterm35-pi4-${TIMESTAMP}.img"

echo "==> 04: Building postmarketOS image for PocketTerm35"

mkdir -p "$IMAGE_DIR"

PMBOOTSTRAP="$(command -v pmbootstrap || echo "$HOME/pmbootstrap/pmbootstrap.py")"
if [ ! -x "$PMBOOTSTRAP" ]; then
    echo "Error: pmbootstrap not found. Run script 01 first."
    exit 1
fi

# ---- Start build ----
echo "==> Starting pmbootstrap install"
echo "    User password / PIN: 0807"
echo "    Target: image file (not SD card)"
echo "    This can take 30-120 minutes (depending on CPU/internet)"
echo ""

# Measure time
START_TIME="$(date +%s)"

# Configure target services via pmbootstrap/QEMU, not an architecture-dependent chroot.
# Install creates the rootfs before we can run target commands.
# Pass password via --password flag (safer than yes-pipe)
"$PMBOOTSTRAP" install --password 0807

# All applications are installed in the first transaction. Current pmbootstrap
# regenerates repositories and does not preserve ad-hoc apk repository tags.
"$PMBOOTSTRAP" chroot -r -- sh -ec '
    for package in postmarketos-ui-phosh calls gnome-calls chatty gnome-contacts; do
        if apk info -e "$package" >/dev/null 2>&1; then
            echo "Unexpected phone application $package; use a clean desktop build." >&2
            exit 1
        fi
    done
    apk info -e nicotine-plus rpi-imager filezilla qbittorrent thunderbird telegram-desktop
'
"$PMBOOTSTRAP" chroot -r -- sh -ec 'id flylopi; apk info -v'  > "$IMAGE_DIR/packages-${TIMESTAMP}.txt"
END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"
echo "==> Build completed in ${DURATION}s"

# ---- Copy image to project directory ----
echo "==> Copying image to $IMAGE_DIR/"

# pmbootstrap stores the image in chroot_native
WORK_DIR="$("$PMBOOTSTRAP" config work 2>/dev/null || echo "$HOME/.local/var/pmbootstrap-pocketterm35-desktop")"
IMG_SRC="$WORK_DIR/chroot_native/home/pmos/rootfs/raspberry-pi4.img"
if [ -f "$IMG_SRC" ]; then
    cp "$IMG_SRC" "$IMAGE_DIR/$IMAGE_NAME"
    echo "    -> $IMAGE_DIR/$IMAGE_NAME"
    ln -sf "$IMAGE_NAME" "$IMAGE_DIR/postmarketOS-latest.img"
    echo "    -> Symlink: images/postmarketOS-latest.img"
else
    echo "ERROR: Expected Pi 4 image missing: $IMG_SRC" >&2
    exit 1
fi

# pmbootstrap shutdown
"$PMBOOTSTRAP" shutdown 2>/dev/null || true

echo ""
echo "==> 04: Done! Image created."
ls -lh "$IMAGE_DIR/$IMAGE_NAME" 2>/dev/null || echo "    (retrieve image manually from $WORK_DIR)"
echo ""
echo "    Next: ./05-post-process.sh"
