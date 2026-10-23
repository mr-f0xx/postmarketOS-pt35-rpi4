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
text = pathlib.Path(sys.argv[1]).read_text(errors='replace')[-3000:]
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print('::error title=Image build failure::' + text)
PY
    native_log="$HOME/.local/var/pmbootstrap-pocketterm35-desktop/log.txt"
    if [ -f "$native_log" ]; then
        python3 - "$native_log" <<'PYLOG'
import pathlib
import re
import sys
text = pathlib.Path(sys.argv[1]).read_text(errors='replace')[-3000:]
text = re.sub(r'\x1b\[[0-9;]*m', '', text)
text = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print('::error title=pmbootstrap failure detail::' + text)
PYLOG
    fi
fi
exit "$status"
