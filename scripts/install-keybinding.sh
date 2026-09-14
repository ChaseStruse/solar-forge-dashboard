#!/usr/bin/env bash
set -euo pipefail

binding_file="${SOLAR_FORGE_BINDINGS_FILE:-$HOME/.config/hypr/bindings.lua}"
binding_json="${SOLAR_FORGE_ACTIVE_BINDINGS_JSON:-}"
marker="-- Solar Forge Dashboard (managed by plugin)"

[[ -f "$binding_file" ]] || {
  echo "keybinding skipped; Hyprland user bindings file was not found"
  exit 0
}

if rg -Fq -- "$marker" "$binding_file"; then
  echo "SUPER + ALT + D keybinding already configured"
  exit 0
fi

if [[ -z "$binding_json" ]]; then
  binding_json=$(hyprctl binds -j 2>/dev/null) || {
    echo "keybinding skipped; active Hyprland bindings were unavailable"
    exit 0
  }
fi

if ! jq -e 'type == "array" and all(.[]; type == "object")' <<<"$binding_json" >/dev/null 2>&1; then
  echo "keybinding skipped; active Hyprland bindings were unreadable"
  exit 0
fi

if jq -e 'any(.[]; (.modmask // 0) == 72 and (((.key // "") | ascii_upcase) == "D" or (.keycode // 0) == 40) and (.submap // "") == "")' \
  <<<"$binding_json" >/dev/null; then
  echo "keybinding skipped; SUPER + ALT + D is already in use"
  exit 0
fi

printf '\n%s\n%s\n' \
  "$marker" \
  'o.bind("SUPER + ALT + D", "Solar Forge Dashboard", "omarchy-shell shell toggle io.github.chasestruse.solar-forge-dashboard")' \
  >>"$binding_file"

echo "installed SUPER + ALT + D keybinding"
