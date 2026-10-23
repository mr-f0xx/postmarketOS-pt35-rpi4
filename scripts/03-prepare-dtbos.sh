#!/bin/sh
# Pinned, byte-identical Waveshare overlay mirror; no fake DTBO fallback.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DTBO_DIR="$PROJECT_DIR/dtbos"
REV=8e5b919390e60f468e534770335abe8ae0cb2451
mkdir -p "$DTBO_DIR"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for file in SHA256SUMS waveshare-35dpi-5b.dtbo; do
    curl -fL "https://api.github.com/repos/therezor/PocketTerm35-OS/contents/boot/$file?ref=$REV" \
        -H 'Accept: application/vnd.github.raw+json' -o "$tmp/$file"
done
(cd "$tmp"; grep 'waveshare-35dpi-5b.dtbo$' SHA256SUMS > selected.sha256; test -s selected.sha256; sha256sum -c selected.sha256)
# Device tree blob magic, not HTML or placeholder text.
test "$(od -An -tx1 -N4 "$tmp/waveshare-35dpi-5b.dtbo" | tr -d ' \n')" = d00dfeed
cp "$tmp/waveshare-35dpi-5b.dtbo" "$DTBO_DIR/"
echo "Verified Waveshare touch overlay ready. See README for provenance."
