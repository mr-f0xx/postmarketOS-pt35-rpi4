#!/bin/sh
# 05-post-process.sh
# Passt das gebaute Image fuer PocketTerm35 an:
#   - config.txt (kernel, initramfs, arm_64bit, include usercfg.txt)
#   - usercfg.txt (vc4-kms-v3d, gpu_mem, plus PocketTerm35 Zusätze)
#   - DTBOs (waveshare-35dpi-5b) in /boot/overlays/
#   - User pmos mit Passwort/PIN 5115
#   - Phosh Autologin + Systemd powersave Service
#   - I2C/RP2040 Tastatur
#   - 3 config-Profile auf boot-Partition

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"
CONFIG_DIR="$PROJECT_DIR/configs"
DTBO_DIR="$PROJECT_DIR/dtbos"

echo "==> 05: Post-Processing – Image fuer PocketTerm35 anpassen"
echo ""

IMAGE="$1"
if [ -z "$IMAGE" ]; then
    IMAGE="$(ls -t "$IMAGE_DIR"/*.img 2>/dev/null | head -1)"
fi
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "Fehler: Kein Image gefunden in $IMAGE_DIR/"
    echo "  Usage: $0 [pfad/zum/image.img]"
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
[ ! -b "$ROOT_PART" ] && { echo "Keine Root-Partition"; exit 1; }

BOOT_MNT="$(mktemp -d /tmp/pmos-boot-XXXXXX)"
ROOT_MNT="$(mktemp -d /tmp/pmos-root-XXXXXX)"
sudo mount "$BOOT_PART" "$BOOT_MNT"
sudo mount "$ROOT_PART" "$ROOT_MNT"

echo "    Boot: $BOOT_PART → $BOOT_MNT"
echo "    Root: $ROOT_PART → $ROOT_MNT"

# ============================================================
# 1. config.txt (Boilerplate + PocketTerm35 + include usercfg)
# ============================================================
echo ""
echo "==> 5.1: config.txt"

copy_profile() {
    local src="$1" dest="$2"
    if [ -f "$src" ]; then
        sudo cp "$src" "$dest"
        echo "    → $(basename $dest)"
    else
        echo "    → FEHLER: $src fehlt"
    fi
}

copy_profile "$CONFIG_DIR/config.txt" "$BOOT_MNT/config.txt"
copy_profile "$CONFIG_DIR/config.txt.powersave" "$BOOT_MNT/config.txt.powersave"
copy_profile "$CONFIG_DIR/config.txt.performance" "$BOOT_MNT/config.txt.performance"
# Symlink balanced → config.txt (bereits kopiert)
[ -f "$CONFIG_DIR/config.txt.balanced" ] && \
    copy_profile "$CONFIG_DIR/config.txt.balanced" "$BOOT_MNT/config.txt.balanced"

# ============================================================
# 2. usercfg.txt (original + PocketTerm35 Zusätze)
# ============================================================
echo ""
echo "==> 5.2: usercfg.txt"

if [ -f "$CONFIG_DIR/usercfg.txt" ]; then
    copy_profile "$CONFIG_DIR/usercfg.txt" "$BOOT_MNT/usercfg.txt"
elif [ -f "$BOOT_MNT/usercfg.txt" ]; then
    # usercfg.txt existiert bereits (vom Device-Package) – PocketTerm35 Dinge anhängen
    echo "    → usercfg.txt vorhanden, hänge PocketTerm35 Overlays an"
    echo "" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "# === PocketTerm35 additions ===" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "dtoverlay=waveshare-35dpi-5b" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
    echo "dtparam=i2c_arm=on" | sudo tee -a "$BOOT_MNT/usercfg.txt" > /dev/null
else
    echo "    → usercfg.txt nicht gefunden, lege an"
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
# 5. Phosh Autologin
# ============================================================
echo ""
echo "==> 5.5: Phosh Autologin"

echo "pmos" | sudo tee "$ROOT_MNT/etc/default-user" > /dev/null
sudo mkdir -p "$ROOT_MNT/etc/systemd/system/getty@tty1.service.d"
sudo tee "$ROOT_MNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p f\\pmos' --autologin pmos --noclear %I 38400 linux
EOF

# ============================================================
# 6. Display-Skalierung 640x480
# ============================================================
echo ""
echo "==> 5.6: Phosh 640x480 Skalierung"

sudo chroot "$ROOT_MNT" /bin/sh -c '
    test -x /usr/bin/gsettings && \
    sudo -u pmos gsettings set org.gnome.mutter experimental-features \
        "[\"scale-monitor-framebuffer\"]" 2>/dev/null || true
' 2>/dev/null || true

# ============================================================
# 7. I2C Tastatur
# ============================================================
echo ""
echo "==> 5.7: I2C/RP2040 Tastatur"

echo "i2c-dev" | sudo tee "$ROOT_MNT/etc/modules-load.d/i2c-dev.conf" > /dev/null
sudo chroot "$ROOT_MNT" /bin/sh -c 'apk add --quiet i2c-tools 2>/dev/null || true' 2>/dev/null || true

# ============================================================
# 8. Systemd powersave Service
# ============================================================
echo ""
echo "==> 5.8: Systemd powersave.service"

sudo tee "$ROOT_MNT/etc/systemd/system/powersave.service" > /dev/null << 'EOF'
[Unit]
Description=PocketTerm35 CPU Powersave (gegen Undervoltage)
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
# Cleanup
# ============================================================
echo ""
echo "==> 5.9: Cleanup"
sync
sudo umount "$BOOT_MNT"
sudo umount "$ROOT_MNT"
rmdir "$BOOT_MNT" "$ROOT_MNT" 2>/dev/null || true
sudo losetup -d "$LOOP_DEV"
trap '' EXIT INT TERM

echo ""
echo "=== 05: Fertig ==="
echo "    Image: $IMAGE"
echo "    Boot:  config.txt + usercfg.txt + Profile"
echo "    User:  pmos / PIN 5115"
echo "    UI:    Phosh (Autologin)"
echo ""
echo "    dd if=$IMAGE of=/dev/sdX bs=4M status=progress"
