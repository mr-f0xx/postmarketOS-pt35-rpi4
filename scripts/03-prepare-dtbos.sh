#!/bin/sh
# 03-prepare-dtbos.sh
# Downloads and extracts the Waveshare PocketTerm35 DTBOs

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DTBO_DIR="$PROJECT_DIR/dtbos"
CONFIG_DIR="$PROJECT_DIR/configs"

echo "==> 03: Downloading Waveshare PocketTerm35 DTBOs"

mkdir -p "$DTBO_DIR" "$CONFIG_DIR"

# ---- 1. DTBO ZIP from Waveshare ----
DTBO_URL="https://files.waveshare.com/wiki/common/3.5HDMI_E_DTBO.zip"
DTBO_ZIP="$DTBO_DIR/3.5HDMI_E_DTBO.zip"

echo "==> Downloading DTBO package from Waveshare..."
if [ ! -f "$DTBO_ZIP" ]; then
    wget -q "$DTBO_URL" -O "$DTBO_ZIP" || curl -sL "$DTBO_URL" -o "$DTBO_ZIP"
    echo "    -> $DTBO_ZIP"
else
    echo "    -> already exists: $DTBO_ZIP"
fi

echo "==> Extracting DTBOs..."
unzip -o "$DTBO_ZIP" -d "$DTBO_DIR" 2>/dev/null || true

# Copy .dtbo files from subdirectories directly into dtbos/
find "$DTBO_DIR" -name '*.dtbo' -exec cp {} "$DTBO_DIR" \; 2>/dev/null || true

echo "==> Found .dtbo files:"
find "$DTBO_DIR" -maxdepth 1 -name '*.dtbo' -exec ls -lh {} \;

# ---- 2. Placeholder if no DTBOs found ----
if ! find "$DTBO_DIR" -maxdepth 1 -name '*.dtbo' 2>/dev/null | grep -q .; then
    echo "Warning: No .dtbo files found in the ZIP."
    echo "Creating placeholder files – please replace manually."
    for overlay in waveshare-35dpi-4b waveshare-35dpi-5b; do
        echo "Placeholder: $overlay.dtbo" > "$DTBO_DIR/$overlay.dtbo"
    done
fi

echo ""
echo "==> DTBOs are ready in: $DTBO_DIR"
echo "    All .dtbo files (flat):"
find "$DTBO_DIR" -maxdepth 1 -name '*.dtbo' -exec echo "      - {}" \;

echo ""
echo "==> 03: Done. Next: ./04-build-image.sh"
