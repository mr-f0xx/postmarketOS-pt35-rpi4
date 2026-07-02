#!/bin/sh
# 05-post-process.sh
# Adapts the built image for PocketTerm35:
#   - config.txt (kernel, initramfs, arm_64bit, include usercfg.txt)
#   - usercfg.txt (vc4-kms-v3d, gpu_mem, plus PocketTerm35 additions)
#   - DTBOs (waveshare-35dpi-5b) in /boot/overlays/
#   - User pmos with password/PIN 5115
#   - Phosh autologin + systemd powersave service
#   - I2C/RP2040 keyboard
#   - 3 config profiles on boot partition

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"
CONFIG_DIR="$PROJECT_DIR/configs"
DTBO_DIR="$PROJECT_DIR/dtbos"

echo "==> 05: Post-processing – adapting image for PocketTerm35"
echo ""

IMAGE="$1"
if [ -z "$IMAGE" ]; then
    IMAGE="$(ls -t "$IMAGE_DIR"/*.img 2>/dev/null | head -1)"
fi
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "Error: No image found in $IMAGE_DIR/"
    echo "  Usage: $0 [path/to/image.img]"
    exit 1
fi
echo "    Image: $IMAGE"

# ---- Mount ----
LOOP_DEV="$(sudo losetup -fP --show "$IMAGE")"
echo "    Loop: $LOOP_DEV"

cleanup() {
    sudo umount "$BOOT_MNT" 2>/dev/null || true
    sudo umount "$ROOT_MNT" 2>/dev/null || true
    rmdir "$BOOT_MNT" "$ROOT_MNT" 2>/dev/null || true
    sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

BOOT_PART="${LOOP_DEV}p1"
ROOT_PART="${LOOP_DEV}p2"
[ ! -b "$BOOT_PART" ] && BOOT_PART="${LOOP_DEV}p0" && ROOT_PART="${LOOP_DEV}p1"
[ ! -b "$ROOT_PART" ] && { echo "No root partition found"; exit 1; }

BOOT_MNT="$(mktemp -d /tmp/pmos-boot-XXXXXX)"
ROOT_MNT="$(mktemp -d /tmp/pmos-root-XXXXXX)"
sudo mount "$BOOT_PART" "$BOOT_MNT"
sudo mount "$ROOT_PART" "$ROOT_MNT"

echo "    Boot: $BOOT_PART → $BOOT_MNT"
echo "    Root: $ROOT_PART → $ROOT_MNT"

# ============================================================
# 1. config.txt (boilerplate + PocketTerm35 + include usercfg)
# ============================================================
echo ""
echo "==> 5.1: config.txt"

copy_profile() {
    local src="$1" dest="$2"
    if [ -f "$src" ]; then
        sudo cp "$src" "$dest"
        echo "    → $(basename $dest)"
    else
        echo "    → ERROR: $src missing"
    fi
}

copy_profile "$CONFIG_DIR/config.txt" "$BOOT_MNT/config.txt"
copy_profile "$CONFIG_DIR/config.txt.powersave" "$BOOT_MNT/config.txt.powersave"
copy_profile "$CONFIG_DIR/config.txt.performance" "$BOOT_MNT/config.txt.performance"
# Symlink balanced → config.txt (already copied)
[ -f "$CONFIG_DIR/config.txt.balanced" ] && \
    copy_profile "$CONFIG_DIR/config.txt.balanced" "$BOOT_MNT/config.txt.balanced"

# ============================================================
# 2. usercfg.txt (original + PocketTerm35 additions)
# ============================================================
echo ""
echo "==> 5.2: usercfg.txt"

if [ -f "$CONFIG_DIR/usercfg.txt" ]; then
    copy_profile "$CONFIG_DIR/usercfg.txt" "$BOOT_MNT/usercfg.txt"
elif [ -f "$BOOT_MNT/usercfg.txt" ]; then
    # usercfg.txt already exists (from device package) – append PocketTerm35 entries
    echo "    → usercfg.txt exists, appending PocketTerm35 overlays"
    echo "" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "# === PocketTerm35 additions ===" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "dtoverlay=waveshare-35dpi-5b" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "dtparam=i2c_arm=on" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
else
    echo "    → usercfg.txt not found, creating it"
    echo "dtoverlay=waveshare-35dpi-5b" | sudo tee "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "dtparam=i2c_arm=on" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
fi

# ============================================================
# 3. DTBOs
# ============================================================
echo ""
echo "==> 5.3: DTBOs → overlays/"

OVERLAY_DIR="$BOOT_MNT/overlays"
sudo mkdir -p "$OVERLAY_DIR"
count=0
for f in "$DTBO_DIR"/waveshare-35dpi-*.dtbo; do
    if [ -f "$f" ]; then
        sudo cp "$f" "$OVERLAY_DIR/"
        echo "    + $(basename $f)"
        count=$((count+1))
    fi
done
echo "    → $count DTBO(s)"

# ============================================================
# 4. User pmos
# ============================================================
echo ""
echo "==> 5.4: User pmos (PIN 5115)"

sudo chroot "$ROOT_MNT" /bin/sh -c '
    if ! id pmos >/dev/null 2>&1; then
        if id user >/dev/null 2>&1; then
            sed -i "s/^user:/pmos:/" /etc/passwd /etc/shadow /etc/group
            [ -f /etc/gshadow ] && sed -i "s/^user:/pmos:/" /etc/gshadow
            [ -d /home/user ] && mv /home/user /home/pmos
        else
            useradd -m -s /bin/bash pmos
        fi
    fi
    echo "pmos:5115" | chpasswd 2>/dev/null || \
        printf "pmos:5115" | chpasswd 2>/dev/null || true
    for g in audio video input netdev plugdev wheel seat feedbackd; do
        adduser pmos $g 2>/dev/null || true
    done
'

# ============================================================
# 5. Phosh autologin
# ============================================================
echo ""
echo "==> 5.5: Phosh autologin"

echo "pmos" | sudo tee "$ROOT_MNT/etc/default-user" > /dev/null
sudo mkdir -p "$ROOT_MNT/etc/systemd/system/getty@tty1.service.d"
sudo tee "$ROOT_MNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p f\\pmos' --autologin pmos --noclear %I 38400 linux
EOF

# ============================================================
# 6. Display scaling 640x480
# ============================================================
echo ""
echo "==> 5.6: Phosh 640x480 scaling"

sudo chroot "$ROOT_MNT" /bin/sh -c '
    test -x /usr/bin/gsettings && \
    sudo -u pmos gsettings set org.gnome.mutter experimental-features \
        "[\"scale-monitor-framebuffer\"]" 2>/dev/null || true
' 2>/dev/null || true

# ============================================================
# 7. I2C keyboard
# ============================================================
echo ""
echo "==> 5.7: I2C/RP2040 keyboard"

echo "i2c-dev" | sudo tee "$ROOT_MNT/etc/modules-load.d/i2c-dev.conf" > /dev/null
sudo chroot "$ROOT_MNT" /bin/sh -c 'apk add --quiet i2c-tools 2>/dev/null || true' 2>/dev/null || true
sudo chroot "$ROOT_MNT" /bin/sh -c 'apk add --quiet growpart parted e2fsprogs 2>/dev/null || true' 2>/dev/null || true

# ============================================================
# 8. Systemd powersave service
# ============================================================
echo ""
echo "==> 5.8: Systemd powersave.service"

sudo tee "$ROOT_MNT/etc/systemd/system/powersave.service" > /dev/null << 'EOF'
[Unit]
Description=PocketTerm35 CPU Powersave (against undervoltage)
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo powersave > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo chroot "$ROOT_MNT" systemctl enable powersave 2>/dev/null || true

# ============================================================
# 9. First-boot partition resize
# ============================================================
echo ""
echo "==> 5.9: First-boot partition resize service"

sudo tee "$ROOT_MNT/usr/local/sbin/resize-rootfs.sh" > /dev/null << 'SCRIPTEOF'
#!/bin/sh
if [ -f /etc/resize-rootfs-done ]; then
    exit 0
fi

ROOT_DEV=$(findmnt -n -o SOURCE /)
case "$ROOT_DEV" in
    /dev/nvme*)
        DISK=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
        PART=$(echo "$ROOT_DEV" | sed 's/.*p//')
        ;;
    /dev/mmcblk*|/dev/loop*)
        DISK=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
        PART=$(echo "$ROOT_DEV" | sed 's/.*p//')
        ;;
    /dev/sd*)
        DISK=$(echo "$ROOT_DEV" | sed 's/[0-9]*$//')
        PART=$(echo "$ROOT_DEV" | sed 's/.*[^0-9]//')
        ;;
    *)
        echo "resize-rootfs: unknown root device $ROOT_DEV"
        exit 1
        ;;
esac

echo "resize-rootfs: expanding $ROOT_DEV on $DISK partition $PART"
growpart "$DISK" "$PART" || echo "resize-rootfs: growpart skipped or failed"
partprobe "$DISK" 2>/dev/null || blockdev --rereadpt "$DISK" 2>/dev/null || echo "resize-rootfs: rereadpt skipped"
resize2fs "$ROOT_DEV" || echo "resize-rootfs: resize2fs failed"

touch /etc/resize-rootfs-done
echo "resize-rootfs: done, rebooting"
reboot
SCRIPTEOF
sudo chmod +x "$ROOT_MNT/usr/local/sbin/resize-rootfs.sh"

sudo tee "$ROOT_MNT/etc/systemd/system/resize-rootfs.service" > /dev/null << 'EOF'
[Unit]
Description=Resize root partition on first boot
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/resize-rootfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo chroot "$ROOT_MNT" systemctl enable resize-rootfs 2>/dev/null || true

# ============================================================
# Cleanup
# ============================================================
echo ""
echo "==> 5.10: Cleanup"
sync
sudo umount "$BOOT_MNT"
sudo umount "$ROOT_MNT"
rmdir "$BOOT_MNT" "$ROOT_MNT" 2>/dev/null || true
sudo losetup -d "$LOOP_DEV"
trap '' EXIT INT TERM

echo ""
echo "=== 05: Done ==="
echo "    Image: $IMAGE"
echo "    Boot:  config.txt + usercfg.txt + profiles"
echo "    User:  pmos / PIN 5115"
echo "    UI:    Phosh (autologin)"
echo ""
echo "    dd if=$IMAGE of=/dev/sdX bs=4M status=progress"
