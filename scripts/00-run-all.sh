#!/bin/sh
# 00-run-all.sh – PocketTerm35 postmarketOS Build Pipeline
# Usage: ./00-run-all.sh
# Individual steps: ./01-*.sh && ./02-*.sh && ...

set -e

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this pipeline as your normal user, not sudo (individual steps request sudo)." >&2
    exit 1
fi
export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==========================================="
echo "  PocketTerm35 postmarketOS Build Pipeline"
echo "==========================================="

step() {
    echo ""
    echo "==========================================="
    echo "  Step $1: $2"
    echo "==========================================="
    cd "$SCRIPT_DIR"
    shift 2
    "$@"
}

step 1 "Install dependencies + pmbootstrap"    sh ./01-install-pmbootstrap.sh
step 2 "Configure pmbootstrap (RPi4, desktop-only Sway)"  sh ./02-configure-pmbootstrap.sh
step 3 "Download Waveshare DTBOs"              sh ./03-prepare-dtbos.sh
step 4 "Build postmarketOS image"              sh ./04-build-image.sh
step 5 "Post-processing (configs, user, DTBOs)" sh ./05-post-process.sh

echo ""
echo "==========================================="
echo "  Build complete!"
echo "==========================================="
echo "  Image:       images/postmarketOS-latest.img"
echo "  User:        flylopi"
echo "  PIN:         0807"
echo "  UI:          PocketTerm35 Sway"
echo ""
echo "  Flash:"
echo "    ./06-flash-nvme.sh"
echo "==========================================="
