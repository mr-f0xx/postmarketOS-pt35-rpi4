#!/bin/bash
# Preserve full logs and expose a bounded failure excerpt in GitHub annotations.
set -u
log=$1
shift
mkdir -p "$(dirname "$log")"
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
    python3 - "$log" <<'PY'
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors='replace')[-10000:]
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print('::error title=Image build failure::' + text)
PY
fi
exit "$status"
