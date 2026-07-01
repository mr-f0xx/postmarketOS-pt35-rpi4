#!/bin/sh
# 06-flash-nvme.sh
# Flashes the built image to a connected NVMe drive

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"

echo "==========================================="
echo "  Flash PocketTerm35 Image to NVMe"
echo "==========================================="
echo ""

# ---- Select image ----
IMAGE="$1"
if [ -z "$IMAGE" ]; then
    IMAGE="$(ls -t "$IMAGE_DIR"/*.img 2>/dev/null | head -1)"
fi
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "Error: No image found."
    echo "  Usage: $0 [path/to/image.img]"
    echo "  Or:    place a .img file in $IMAGE_DIR/"
    exit 1
fi
echo "Image: $IMAGE ($(du -h "$IMAGE" | cut -f1))"

# ---- List NVMe devices ----
echo ""
echo "Found NVMe devices:"
lsblk -d -o NAME,SIZE,MODEL,TRAN -e 2,11 2>/dev/null | grep nvme || echo "  (no NVMe found)"
echo ""

NVME_DEV=""
AVAILABLE_NVME=""
for dev in /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1; do
    if [ -b "$dev" ]; then
        model="$(cat /sys/block/$(basename $dev)/device/model 2>/dev/null || echo "NVMe")"
        size="$(lsblk -dn -o SIZE "$dev" 2>/dev/null)"
        AVAILABLE_NVME="$AVAILABLE_NVME    $dev - $model ($size)\n"
    fi
done

if [ -z "$AVAILABLE_NVME" ]; then
    echo "ERROR: No NVMe device found."
    echo ""
    echo "Possible reasons:"
    echo "  - NVMe not connected / not detected"
    echo "  - No permission (run script with sudo)"
    echo "  - PCIe NVMe adapter not properly seated in PocketTerm35"
    exit 1
fi

echo "Available NVMe devices:"
printf "$AVAILABLE_NVME"
echo ""

# ---- Select target ----
if [ $(printf "$AVAILABLE_NVME" | wc -l) -eq 1 ]; then
    NVME_DEV="$(printf "$AVAILABLE_NVME" | grep -o '/dev/nvme[0-9]n[0-9]' | head -1)"
    echo "-> Single NVMe: $NVME_DEV"
else
    echo "Please enter target NVMe (e.g. /dev/nvme0n1):"
    printf "> "
    read NVME_DEV
fi

if [ ! -b "$NVME_DEV" ]; then
    echo "ERROR: $NVME_DEV is not a block device."
    exit 1
fi

# ---- Safety check ----
echo ""
echo "==========================================="
echo "  WARNING! ALL DATA ON $NVME_DEV WILL BE ERASED!"
echo "==========================================="
echo "  Image:  $IMAGE"
echo "  Target: $NVME_DEV"
echo "  Size:   $(lsblk -dn -o SIZE $NVME_DEV)"
echo ""
echo "  Type 'yes' to confirm: "
printf "> "
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# ---- Check if image fits on target ----
IMAGE_SIZE="$(stat -c%s "$IMAGE")"
NVME_SIZE="$(cat /sys/block/$(basename $NVME_DEV)/size)"
NVME_SIZE_BYTES="$((NVME_SIZE * 512))"

if [ "$IMAGE_SIZE" -gt "$NVME_SIZE_BYTES" ]; then
    echo "ERROR: Image ($IMAGE_SIZE bytes) is larger than NVMe ($NVME_SIZE_BYTES bytes)"
    exit 1
fi

# ---- Flash ----
echo ""
echo "==> Flashing $IMAGE -> $NVME_DEV ..."
echo "    This may take a few minutes."

START_TIME="$(date +%s)"

# Flash with dd
sudo dd if="$IMAGE" of="$NVME_DEV" bs=4M status=progress conv=fsync

END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"

# sync
echo ""
echo "==> Syncing..."
sync

# ---- Re-read partition table ----
echo "==> Re-reading partition table..."
sudo partprobe "$NVME_DEV" 2>/dev/null || sudo blockdev --rereadpt "$NVME_DEV" 2>/dev/null || true

echo ""
echo "==========================================="
echo "  Done! Image flashed successfully!"
echo "==========================================="
echo "  Target:  $NVME_DEV"
echo "  Image:   $(basename "$IMAGE")"
echo "  Time:    ${DURATION}s"
echo "  Speed:   $(( IMAGE_SIZE / 1048576 / (DURATION + 1) )) MB/s"
echo ""
echo "  Now insert into PocketTerm35 and power on:"
echo "  - After the first boot the root partition will be"
echo "    automatically expanded to the full NVMe size"
echo "  - User: pmos"
echo "  - PIN:  5115"
echo "==========================================="
