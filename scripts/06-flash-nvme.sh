#!/bin/sh
# 06-flash-nvme.sh
# Flasht das gebaute Image auf einen angeschlossenen NVMe-Drive

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"

echo "==========================================="
echo "  PocketTerm35 Image auf NVME flashen"
echo "==========================================="
echo ""

# ---- Image auswaehlen ----
IMAGE="$1"
if [ -z "$IMAGE" ]; then
    IMAGE="$(ls -t "$IMAGE_DIR"/*.img 2>/dev/null | head -1)"
fi
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "Fehler: Kein Image gefunden."
    echo "  Usage: $0 [pfad/zum/image.img]"
    echo "  Oder:  lege ein .img in $IMAGE_DIR/"
    exit 1
fi
echo "Image: $IMAGE ($(du -h "$IMAGE" | cut -f1))"

# ---- NVMe-Geraete auflisten ----
echo ""
echo "Gefundene NVMe-Geraete:"
lsblk -d -o NAME,SIZE,MODEL,TRAN -e 2,11 2>/dev/null | grep nvme || echo "  (keine NVMe gefunden)"
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
    echo "FEHLER: Kein NVMe-Geraet gefunden."
    echo ""
    echo "Moegliche Gruende:"
    echo "  - NVMe nicht angeschlossen / nicht erkannt"
    echo "  - Keine Berechtigung (Script als sudo ausfuehren)"
    echo "  - PCIe NVMe Adapter nicht korrekt im PocketTerm35"
    exit 1
fi

echo "Verfuegbare NVMe-Geraete:"
printf "$AVAILABLE_NVME"
echo ""

# ---- Ziel auswaehlen ----
if [ $(printf "$AVAILABLE_NVME" | wc -l) -eq 1 ]; then
    NVME_DEV="$(printf "$AVAILABLE_NVME" | grep -o '/dev/nvme[0-9]n[0-9]' | head -1)"
    echo "-> Einziges NVMe: $NVME_DEV"
else
    echo "Bitte Ziel-NVMe eingeben (z.B. /dev/nvme0n1):"
    printf "> "
    read NVME_DEV
fi

if [ ! -b "$NVME_DEV" ]; then
    echo "FEHLER: $NVME_DEV ist kein Blockdevice."
    exit 1
fi

# ---- Sicherheitscheck ----
echo ""
echo "==========================================="
echo "  ACHTUNG! ALLE DATEN AUF $NVME_DEV WERDEN GELOESCHT!"
echo "==========================================="
echo "  Image:  $IMAGE"
echo "  Ziel:   $NVME_DEV"
echo "  Groesse: $(lsblk -dn -o SIZE $NVME_DEV)"
echo ""
echo "  'yes' eingeben um zu bestaetigen: "
printf "> "
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Abbruch."
    exit 1
fi

# ---- Pruefen ob Image auf Ziel passt ----
IMAGE_SIZE="$(stat -c%s "$IMAGE")"
NVME_SIZE="$(cat /sys/block/$(basename $NVME_DEV)/size)"
NVME_SIZE_BYTES="$((NVME_SIZE * 512))"

if [ "$IMAGE_SIZE" -gt "$NVME_SIZE_BYTES" ]; then
    echo "FEHLER: Image ($IMAGE_SIZE Bytes) ist groesser als NVMe ($NVME_SIZE_BYTES Bytes)"
    exit 1
fi

# ---- Flashen ----
echo ""
echo "==> Flashe $IMAGE -> $NVME_DEV ..."
echo "    Das kann einige Minuten dauern."

START_TIME="$(date +%s)"

# Mit dd flashen
sudo dd if="$IMAGE" of="$NVME_DEV" bs=4M status=progress conv=fsync

END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"

# sync
echo ""
echo "==> Sync..."
sync

# ---- Partitions-Tabelle neu einlesen ----
echo "==> Lese Partitionstabelle neu ein..."
sudo partprobe "$NVME_DEV" 2>/dev/null || sudo blockdev --rereadpt "$NVME_DEV" 2>/dev/null || true

echo ""
echo "==========================================="
echo "  Fertig! Image erfolgreich geflasht!"
echo "==========================================="
echo "  Ziel:     $NVME_DEV"
echo "  Image:    $(basename "$IMAGE")"
echo "  Dauer:    ${DURATION}s"
echo "  Geschw:   $(( IMAGE_SIZE / 1048576 / (DURATION + 1) )) MB/s"
echo ""
echo "  Jetzt in PocketTerm35 einschalten:"
echo "  - Nach dem ersten Boot wird die Root-Partition automatisch"
echo "    auf die volle NVMe-Groesse erweitert"
echo "  - User: pmos"
echo "  - PIN:  5115"
echo "==========================================="
