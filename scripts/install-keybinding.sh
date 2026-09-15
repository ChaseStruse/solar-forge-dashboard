#!/usr/bin/env bash
set -euo pipefail

binding_file="${SOLAR_FORGE_BINDINGS_FILE:-$HOME/.config/hypr/bindings.lua}"
# Edit the target of a dotfiles symlink so removal does not replace the link.
if [[ -L "$binding_file" ]]; then
  binding_file=$(readlink -f -- "$binding_file")
fi
binding_json="${SOLAR_FORGE_ACTIVE_BINDINGS_JSON:-}"
marker="-- Solar Forge Dashboard (managed by plugin)"
binding='o.bind("SUPER + ALT + D", "Solar Forge Dashboard", "omarchy-shell shell toggle io.github.chasestruse.solar-forge-dashboard")'
action="${1:---install}"

case "$action" in
  --status)
    if [[ -f "$binding_file" ]] && rg -Fq -- "$marker" "$binding_file"; then
      echo "configured"
    else
      echo "not-configured"
    fi
    exit 0
    ;;
  --remove)
    [[ -f "$binding_file" ]] || {
      echo "SUPER + ALT + D keybinding is not configured"
      exit 0
    }
    if ! rg -Fq -- "$marker" "$binding_file"; then
      echo "SUPER + ALT + D keybinding is not configured"
      exit 0
    fi
    temporary_file="$(mktemp "${binding_file}.solar-forge.XXXXXX")"
    trap 'rm -f "$temporary_file"' EXIT
    awk -v marker="$marker" -v binding="$binding" '
      $0 == marker { skip_binding = 1; next }
      skip_binding && $0 == binding { skip_binding = 0; next }
      { skip_binding = 0; print }
    ' "$binding_file" >"$temporary_file"
    chmod --reference="$binding_file" "$temporary_file"
    mv -- "$temporary_file" "$binding_file"
    trap - EXIT
    echo "removed SUPER + ALT + D keybinding"
    exit 0
    ;;
  --install) ;;
  *)
    echo "usage: $0 [--install|--remove|--status]" >&2
    exit 2
    ;;
esac

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
  "$binding" \
  >>"$binding_file"

echo "installed SUPER + ALT + D keybinding"
