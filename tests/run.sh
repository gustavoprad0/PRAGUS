#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_qmake="$(command -v qmake6 || command -v qmake || true)"
if [[ -z "$task_qmake" && -x /usr/lib/qt6/bin/qmake ]]; then task_qmake=/usr/lib/qt6/bin/qmake; fi
if [[ -z "$task_qmake" ]]; then echo 'Instale o qmake do Qt 6.' >&2; exit 1; fi
task_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/pragus-tests.XXXXXX")"
trap 'rm -rf "$task_test_dir"' EXIT
"$task_root/build.sh"
for task_suite in chathistory chatclient_test; do
    mkdir "$task_test_dir/$task_suite"
    cd "$task_test_dir/$task_suite"
    "$task_qmake" "$task_root/tests/$task_suite.pro"
    make -j2
    if [[ "$task_suite" == chathistory ]]; then
        ./chathistory_test
    else
        QT_QPA_PLATFORM=offscreen ./chatclient_test
    fi
done
