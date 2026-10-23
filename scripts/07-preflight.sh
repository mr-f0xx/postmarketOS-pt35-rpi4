#!/bin/sh
# Host-side checks only: never mounts, flashes or modifies a block device.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$PROJECT_DIR"
python3 -m unittest discover -s tests -v
for cmd in git python3 curl sudo losetup mount umount sha256sum; do
    command -v "$cmd" >/dev/null || { echo "Missing build tool: $cmd" >&2; exit 1; }
done
PMBOOTSTRAP=$(command -v pmbootstrap || printf '%s' "$HOME/pmbootstrap/pmbootstrap.py")
[ -x "$PMBOOTSTRAP" ] || { echo 'pmbootstrap not installed; run step 01 on the Linux build host.' >&2; exit 1; }
"$PMBOOTSTRAP" --version
[ "$("$PMBOOTSTRAP" config device)" = raspberry-pi4 ]
echo 'Host preflight passed. Full build still needs upstream GitLab/Alpine access and loop-device privileges.'
