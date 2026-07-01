#!/bin/sh
# 00-run-all.sh – PocketTerm35 postmarketOS Build Pipeline
# Usage: ./00-run-all.sh
# Individual steps: ./01-*.sh && ./02-*.sh && ...

set -e

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
step 2 "Configure pmbootstrap (RPi5 + Phosh)"  sh ./02-configure-pmbootstrap.sh
step 3 "Download Waveshare DTBOs"              sh ./03-prepare-dtbos.sh
step 4 "Build postmarketOS image"              sh ./04-build-image.sh
step 5 "Post-processing (configs, user, DTBOs)" sudo sh ./05-post-process.sh

echo ""
echo "==========================================="
echo "  Build complete!"
echo "==========================================="
echo "  Image:       images/postmarketOS-latest.img"
echo "  User:        pmos"
echo "  PIN:         5115"
echo "  UI:          Phosh (Autologin)"
echo ""
echo "  Flash:"
echo "    ./06-flash-nvme.sh"
echo "==========================================="
