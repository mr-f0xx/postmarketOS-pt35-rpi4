#!/bin/sh
# 00-run-all.sh – PocketTerm35 postmarketOS Build Pipeline
# Usage: ./00-run-all.sh
# Einzelschritte: ./01-*.sh && ./02-*.sh && ...

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==========================================="
echo "  PocketTerm35 postmarketOS Build Pipeline"
echo "==========================================="

step() {
    echo ""
    echo "==========================================="
    echo "  Schritt $1: $2"
    echo "==========================================="
    cd "$SCRIPT_DIR"
    shift 2
    "$@"
}

step 1 "Installiere Abhaengigkeiten + pmbootstrap" sh ./01-install-pmbootstrap.sh
step 2 "Konfiguriere pmbootstrap (RPi5 + Phosh)"    sh ./02-configure-pmbootstrap.sh
step 3 "Lade Waveshare DTBOs herunter"              sh ./03-prepare-dtbos.sh
step 4 "Baue postmarketOS Image"                    sh ./04-build-image.sh
step 5 "Post-Processing (configs, User, DTBOs)"     sudo sh ./05-post-process.sh

echo ""
echo "==========================================="
echo "  Build abgeschlossen!"
echo "==========================================="
echo "  Image:       images/postmarketOS-latest.img"
echo "  User:        pmos"
echo "  PIN:         5115"
echo "  UI:          Phosh (Autologin)"
echo ""
echo "  Flashen:"
echo "    ./06-flash-nvme.sh"
echo "==========================================="
