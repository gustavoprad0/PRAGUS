#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QMAKE="$(command -v qmake6 || command -v qmake || true)"
if [[ -z "$QMAKE" && -x /usr/lib/qt6/bin/qmake ]]; then QMAKE=/usr/lib/qt6/bin/qmake; fi
if [[ -z "$QMAKE" ]]; then echo "Instale as ferramentas de desenvolvimento do Qt 6 (qmake)." >&2; exit 1; fi
task_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-desk-build.XXXXXX")"
trap 'rm -rf "$task_build_dir"' EXIT
cd "$task_build_dir"
"$QMAKE" "$ROOT/native/bridge.pro"
make -j2
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys, zipfile
root = Path(sys.argv[1])
with zipfile.ZipFile(root / 'codex-desk.plasmoid', 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted((root / 'package').rglob('*')):
        if p.is_file():
            z.write(p, p.relative_to(root / 'package'))
print(root / 'codex-desk.plasmoid')
PY
