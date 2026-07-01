#!/bin/sh
# 04-build-image.sh
# Builds the postmarketOS image for PocketTerm35 with Phosh
# Set PMB_SUDO for passwordless sudo (wrapper) or ensure
# the user can run sudo without a password.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IMAGE_NAME="postmarketOS-pocketterm35-phosh-${TIMESTAMP}.img"

echo "==> 04: Building postmarketOS image for PocketTerm35"

mkdir -p "$IMAGE_DIR"

PMBOOTSTRAP="$(command -v pmbootstrap || echo "$HOME/pmbootstrap/pmbootstrap.py")"
if [ ! -x "$PMBOOTSTRAP" ]; then
    echo "Error: pmbootstrap not found. Run script 01 first."
    exit 1
fi

# ---- Start build ----
echo "==> Starting pmbootstrap install"
echo "    User password / PIN: 5115"
echo "    Target: image file (not SD card)"
echo "    This can take 30-120 minutes (depending on CPU/internet)"
echo ""

# Measure time
START_TIME="$(date +%s)"

# Pass password via --password flag (safer than yes-pipe)
"$PMBOOTSTRAP" install --password 5115

END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"
echo "==> Build completed in ${DURATION}s"

# ---- Copy image to project directory ----
echo "==> Copying image to $IMAGE_DIR/"

# pmbootstrap stores the image in chroot_native
WORK_DIR="$("$PMBOOTSTRAP" config work 2>/dev/null || echo "$HOME/.local/var/pmbootstrap")"
IMG_SRC="$WORK_DIR/chroot_native/home/pmos/rootfs/raspberry-pi5.img"
if [ -f "$IMG_SRC" ]; then
    cp "$IMG_SRC" "$IMAGE_DIR/$IMAGE_NAME"
    echo "    -> $IMAGE_DIR/$IMAGE_NAME"
    ln -sf "$IMAGE_NAME" "$IMAGE_DIR/postmarketOS-latest.img"
    echo "    -> Symlink: images/postmarketOS-latest.img"
else
    # Fallback: search images directory
    LATEST_IMG="$(ls -t "$WORK_DIR"/images/*.img 2>/dev/null | head -1)"
    if [ -n "$LATEST_IMG" ]; then
        cp "$LATEST_IMG" "$IMAGE_DIR/$IMAGE_NAME"
        echo "    -> $IMAGE_DIR/$IMAGE_NAME"
    else
        echo "Warning: Image not found automatically."
        echo "  -> Search in: $WORK_DIR"
    fi
fi

# pmbootstrap shutdown
"$PMBOOTSTRAP" shutdown 2>/dev/null || true

echo ""
echo "==> 04: Done! Image created."
ls -lh "$IMAGE_DIR/$IMAGE_NAME" 2>/dev/null || echo "    (retrieve image manually from $WORK_DIR)"
echo ""
echo "    Next: sudo ./05-post-process.sh"
