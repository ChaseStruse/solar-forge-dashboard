#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d /tmp/solar-forge-keybinding.XXXXXX)"
installer="$project_dir/scripts/install-keybinding.sh"

free_file="$test_dir/free.lua"
printf '%s\n' '-- user bindings' >"$free_file"
SOLAR_FORGE_BINDINGS_FILE="$free_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" >/dev/null
rg -Fq 'o.bind("SUPER + ALT + D", "Solar Forge Dashboard"' "$free_file"
SOLAR_FORGE_BINDINGS_FILE="$free_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" >/dev/null
[[ $(rg -Fc 'Solar Forge Dashboard (managed by plugin)' "$free_file") -eq 1 ]]

occupied_file="$test_dir/occupied.lua"
printf '%s\n' '-- user bindings' >"$occupied_file"
occupied='[{"modmask":72,"key":"D","submap":"","description":"Existing binding"}]'
SOLAR_FORGE_BINDINGS_FILE="$occupied_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON="$occupied" bash "$installer" >/dev/null
! rg -q 'Solar Forge Dashboard' "$occupied_file"

for invalid in 'not json' '{}' 'null'; do
  SOLAR_FORGE_BINDINGS_FILE="$occupied_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON="$invalid" bash "$installer" >/dev/null
  ! rg -q 'Solar Forge Dashboard' "$occupied_file"
done
SOLAR_FORGE_BINDINGS_FILE="$occupied_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[{"modmask":72,"keycode":40}]' bash "$installer" >/dev/null
! rg -q 'Solar Forge Dashboard' "$occupied_file"

echo "Keybinding installer checks passed. Test files: $test_dir"
