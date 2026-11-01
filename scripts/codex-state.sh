#!/usr/bin/env bash
# Described Hyprland keybindings for the Codex module.
set -uo pipefail
hyprctl binds -j 2>/dev/null | jq -c '{binds: [ .[] | select(.has_description and .submap == "")
  | {modmask, key, description, mouse} ] }' || echo '{"binds": []}'
