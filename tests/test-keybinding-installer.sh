#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d /tmp/solar-forge-keybinding.XXXXXX)"
installer="$project_dir/scripts/install-keybinding.sh"

free_file="$test_dir/free.lua"
printf '%s\n' '-- user bindings' >"$free_file"
[[ $(SOLAR_FORGE_BINDINGS_FILE="$free_file" bash "$installer" --status) == "not-configured" ]]
SOLAR_FORGE_BINDINGS_FILE="$free_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" >/dev/null
rg -Fq 'o.bind("SUPER + ALT + D", "Solar Forge Dashboard"' "$free_file"
[[ $(SOLAR_FORGE_BINDINGS_FILE="$free_file" bash "$installer" --status) == "configured" ]]
SOLAR_FORGE_BINDINGS_FILE="$free_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" >/dev/null
[[ $(rg -Fc 'Solar Forge Dashboard (managed by plugin)' "$free_file") -eq 1 ]]
SOLAR_FORGE_BINDINGS_FILE="$free_file" bash "$installer" --remove >/dev/null
! rg -q 'Solar Forge Dashboard' "$free_file"
[[ $(SOLAR_FORGE_BINDINGS_FILE="$free_file" bash "$installer" --status) == "not-configured" ]]
SOLAR_FORGE_BINDINGS_FILE="$free_file" bash "$installer" --remove >/dev/null

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

linked_file="$test_dir/linked.lua"
ln -s "$free_file" "$linked_file"
SOLAR_FORGE_BINDINGS_FILE="$linked_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" >/dev/null
SOLAR_FORGE_BINDINGS_FILE="$linked_file" bash "$installer" --remove >/dev/null
[[ -L "$linked_file" ]]
! rg -q 'Solar Forge Dashboard' "$free_file"


# Launcher binding: independent marker, own conflict check, survives
# alongside the dashboard binding, and points at the bundled script.
launcher_file="$test_dir/launcher.lua"
printf '%s\n' '-- user bindings' >"$launcher_file"
[[ $(SOLAR_FORGE_BINDINGS_FILE="$launcher_file" bash "$installer" --status launcher) == "not-configured" ]]
SOLAR_FORGE_BINDINGS_FILE="$launcher_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" --install dashboard >/dev/null
SOLAR_FORGE_BINDINGS_FILE="$launcher_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON='[]' bash "$installer" --install launcher >/dev/null
rg -Fq 'o.bind("SUPER + ALT + L", "Solar Forge Launcher", "bash ' "$launcher_file"
rg -Fq 'scripts/launcher-shortcut.sh")' "$launcher_file"
[[ $(SOLAR_FORGE_BINDINGS_FILE="$launcher_file" bash "$installer" --status launcher) == "configured" ]]
SOLAR_FORGE_BINDINGS_FILE="$launcher_file" bash "$installer" --remove launcher >/dev/null
! rg -q 'Solar Forge Launcher' "$launcher_file"
rg -Fq 'o.bind("SUPER + ALT + D", "Solar Forge Dashboard"' "$launcher_file"
taken_l='[{"modmask":72,"key":"L","submap":""}]'
SOLAR_FORGE_BINDINGS_FILE="$launcher_file" SOLAR_FORGE_ACTIVE_BINDINGS_JSON="$taken_l" bash "$installer" --install launcher >/dev/null
! rg -q 'Solar Forge Launcher' "$launcher_file"
[[ $(bash "$installer" --install bogus 2>/dev/null; echo $?) == 2 ]]
echo "Keybinding installer checks passed. Test files: $test_dir"
