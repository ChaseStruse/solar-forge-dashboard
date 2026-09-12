#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d /tmp/solar-forge-check.XXXXXX)"
# Keep the temporary run for debugging; never use the user's real task database.
cp "$project_dir/"*.qml "$test_dir/"
cp "$project_dir/tests/shell.qml" "$test_dir/shell.qml"
ln -s /usr/share/omarchy/shell/Commons "$test_dir/Commons"
ln -s /usr/share/omarchy/shell/Ui "$test_dir/Ui"
mkdir -m 700 "$test_dir/runtime"
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_CONTROLS_STYLE=Basic \
  XDG_DATA_HOME="$test_dir/data" XDG_RUNTIME_DIR="$test_dir/runtime" \
  timeout 20s quickshell -p "$test_dir/shell.qml" 2>&1 | tee "$test_dir/test.log"
rg -q SOLAR_FORGE_TESTS_PASSED "$test_dir/test.log"
if rg 'SOLAR_FORGE_TESTS_FAILED|TypeError|ReferenceError|ERROR' "$test_dir/test.log" \
  | rg -qv 'quickshell\.ipc: Failed to start IPC server'; then exit 1; fi
echo "Checks passed. Test files: $test_dir"
