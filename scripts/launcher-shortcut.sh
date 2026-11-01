#!/usr/bin/env bash
# SUPER + ALT + L: open Solar Forge straight into Launch Control.
# An already-open deck switches (or closes) in place; otherwise the plugin
# arms the launcher and the shell summons the deck on the focused monitor.
set -uo pipefail

result=$(omarchy-shell -q solar-forge launcher 2>/dev/null)
if [[ "$result" == "armed" ]]; then
  omarchy-shell -q shell summon io.github.chasestruse.solar-forge-dashboard '{}' >/dev/null
fi
