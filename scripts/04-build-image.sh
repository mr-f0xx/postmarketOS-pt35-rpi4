#!/bin/sh
# 04-build-image.sh
# Baut das postmarketOS Image fuer PocketTerm35 mit Phosh
# Setzt PMB_SUDO fuer passwortloses sudo (Wrapper) oder stelle sicher
# dass der Benutzer sudo ohne Passwort ausfuehren kann.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_DIR="$PROJECT_DIR/images"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IMAGE_NAME="postmarketOS-pocketterm35-phosh-${TIMESTAMP}.img"

echo "==> 04: Baue postmarketOS Image fuer PocketTerm35"

mkdir -p "$IMAGE_DIR"

PMBOOTSTRAP="$(command -v pmbootstrap || echo "$HOME/pmbootstrap/pmbootstrap.py")"
if [ ! -x "$PMBOOTSTRAP" ]; then
    echo "Fehler: pmbootstrap nicht gefunden. Fuehre zuerst Script 01 aus."
    exit 1
fi

# ---- Build starten ----
echo "==> Starte pmbootstrap install"
echo "    User-Passwort / PIN: 5115"
echo "    Ziel: Image-Datei (keine SD-Karte)"
echo "    Das kann 30-120 Minuten dauern (je nach CPU/Internet)"
echo ""

# Zeitmessung
START_TIME="$(date +%s)"

# Passwort per --password-Flag (sicherer als yes-Pipe)
"$PMBOOTSTRAP" install --password 5115

END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"
echo "==> Build abgeschlossen in ${DURATION}s"

# ---- Image ins Projektverzeichnis kopieren ----
echo "==> Kopiere Image nach $IMAGE_DIR/"

# pmbootstrap speichert das Image im chroot_native
WORK_DIR="$("$PMBOOTSTRAP" config work 2>/dev/null || echo "$HOME/.local/var/pmbootstrap")"
IMG_SRC="$WORK_DIR/chroot_native/home/pmos/rootfs/raspberry-pi5.img"
if [ -f "$IMG_SRC" ]; then
    cp "$IMG_SRC" "$IMAGE_DIR/$IMAGE_NAME"
    echo "    -> $IMAGE_DIR/$IMAGE_NAME"
    ln -sf "$IMAGE_NAME" "$IMAGE_DIR/postmarketOS-latest.img"
    echo "    -> Symlink: images/postmarketOS-latest.img"
else
    # Fallback: images-Verzeichnis durchsuchen
    LATEST_IMG="$(ls -t "$WORK_DIR"/images/*.img 2>/dev/null | head -1)"
    if [ -n "$LATEST_IMG" ]; then
        cp "$LATEST_IMG" "$IMAGE_DIR/$IMAGE_NAME"
        echo "    -> $IMAGE_DIR/$IMAGE_NAME"
    else
        echo "Warnung: Image nicht automatisch gefunden."
        echo "  -> Suche in: $WORK_DIR"
    fi
fi

# pmbootstrap shutdown
"$PMBOOTSTRAP" shutdown 2>/dev/null || true

echo ""
echo "==> 04: Fertig! Image erstellt."
ls -lh "$IMAGE_DIR/$IMAGE_NAME" 2>/dev/null || echo "    (Image manuell aus $WORK_DIR holen)"
echo ""
echo "    Weiter mit: sudo ./05-post-process.sh"
