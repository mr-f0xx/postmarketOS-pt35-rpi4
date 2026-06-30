#!/bin/sh
# 03-prepare-dtbos.sh
# Laedt die Waveshare PocketTerm35 DTBOs herunter und entpackt sie

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DTBO_DIR="$PROJECT_DIR/dtbos"
CONFIG_DIR="$PROJECT_DIR/configs"

echo "==> 03: Lade Waveshare PocketTerm35 DTBOs herunter"

mkdir -p "$DTBO_DIR" "$CONFIG_DIR"

# ---- 1. DTBO ZIP von Waveshare ----
DTBO_URL="https://files.waveshare.com/wiki/common/3.5HDMI_E_DTBO.zip"
DTBO_ZIP="$DTBO_DIR/3.5HDMI_E_DTBO.zip"

echo "==> Downloade DTBO-Paket von Waveshare..."
if [ ! -f "$DTBO_ZIP" ]; then
    wget -q "$DTBO_URL" -O "$DTBO_ZIP" || curl -sL "$DTBO_URL" -o "$DTBO_ZIP"
    echo "    -> $DTBO_ZIP"
else
    echo "    -> bereits vorhanden: $DTBO_ZIP"
fi

echo "==> Entpacke DTBOs..."
unzip -o "$DTBO_ZIP" -d "$DTBO_DIR" 2>/dev/null || true

# Kopiere .dtbo Dateien aus Unterverzeichnissen direkt nach dtbos/
find "$DTBO_DIR" -name '*.dtbo' -exec cp {} "$DTBO_DIR" \; 2>/dev/null || true

echo "==> Enthaltene .dtbo Dateien:"
find "$DTBO_DIR" -maxdepth 1 -name '*.dtbo' -exec ls -lh {} \;

# ---- 2. Platzhalter falls keine DTBOs gefunden ----
if ! find "$DTBO_DIR" -maxdepth 1 -name '*.dtbo' 2>/dev/null | grep -q .; then
    echo "Warnung: Keine .dtbo Dateien in der ZIP gefunden."
    echo "Erstelle Platzhalter-Dateien – bitte manuell ersetzen."
    for overlay in waveshare-35dpi-4b waveshare-35dpi-5b; do
        echo "Platzhalter: $overlay.dtbo" > "$DTBO_DIR/$overlay.dtbo"
    done
fi

echo ""
echo "==> DTBOs sind bereit in: $DTBO_DIR"
echo "    Alle .dtbo (flach):"
find "$DTBO_DIR" -maxdepth 1 -name '*.dtbo' -exec echo "      - {}" \;

echo ""
echo "==> 03: Fertig. Weiter mit: ./04-build-image.sh"
