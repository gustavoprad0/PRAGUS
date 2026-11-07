#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT/build.sh"
if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/local.codex.desk" ]]; then
    kpackagetool6 -t Plasma/Applet -u "$ROOT/codex-desk.plasmoid"
else
    kpackagetool6 -t Plasma/Applet -i "$ROOT/codex-desk.plasmoid"
fi
echo 'Instalado. Em Adicionar ou gerenciar widgets, procure PRAGUS.'
