#!/usr/bin/env bash
set -euo pipefail

binding_file="${SOLAR_FORGE_BINDINGS_FILE:-$HOME/.config/hypr/bindings.lua}"
# Edit the target of a dotfiles symlink so removal does not replace the link.
if [[ -L "$binding_file" ]]; then
  binding_file=$(readlink -f -- "$binding_file")
fi
binding_json="${SOLAR_FORGE_ACTIVE_BINDINGS_JSON:-}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
action="${1:---install}"
target="${2:-dashboard}"

# Each managed binding: chord label, Hyprland modmask/key/keycode for the
# conflict check, marker comment, and the bind line itself.
case "$target" in
  dashboard)
    chord="SUPER + ALT + D"; modmask=72; key="D"; keycode=40
    marker="-- Solar Forge Dashboard (managed by plugin)"
    binding='o.bind("SUPER + ALT + D", "Solar Forge Dashboard", "omarchy-shell shell toggle io.github.chasestruse.solar-forge-dashboard")'
    ;;
  launcher)
    chord="SUPER + ALT + L"; modmask=72; key="L"; keycode=46
    marker="-- Solar Forge Launcher (managed by plugin)"
    binding="o.bind(\"SUPER + ALT + L\", \"Solar Forge Launcher\", \"bash $script_dir/launcher-shortcut.sh\")"
    ;;
  *)
    echo "usage: $0 [--install|--remove|--status] [dashboard|launcher]" >&2
    exit 2
    ;;
esac

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
    if [[ ! -f "$binding_file" ]] || ! rg -Fq -- "$marker" "$binding_file"; then
      echo "$chord keybinding is not configured"
      exit 0
    fi
    temporary_file="$(mktemp "${binding_file}.solar-forge.XXXXXX")"
    trap 'rm -f "$temporary_file"' EXIT
    # Drop the marker and the managed line directly beneath it, whatever its
    # recorded script path, so moved installs still clean up.
    awk -v marker="$marker" '
      $0 == marker { skip_binding = 1; next }
      skip_binding && index($0, "o.bind(") == 1 { skip_binding = 0; next }
      { skip_binding = 0; print }
    ' "$binding_file" >"$temporary_file"
    chmod --reference="$binding_file" "$temporary_file"
    mv -- "$temporary_file" "$binding_file"
    trap - EXIT
    echo "removed $chord keybinding"
    exit 0
    ;;
  --install) ;;
  *)
    echo "usage: $0 [--install|--remove|--status] [dashboard|launcher]" >&2
    exit 2
    ;;
esac

[[ -f "$binding_file" ]] || {
  echo "keybinding skipped; Hyprland user bindings file was not found"
  exit 0
}

if rg -Fq -- "$marker" "$binding_file"; then
  echo "$chord keybinding already configured"
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

if jq -e --argjson mask "$modmask" --arg key "$key" --argjson code "$keycode" \
  'any(.[]; (.modmask // 0) == $mask and (((.key // "") | ascii_upcase) == $key or (.keycode // 0) == $code) and (.submap // "") == "")' \
  <<<"$binding_json" >/dev/null; then
  echo "keybinding skipped; $chord is already in use"
  exit 0
fi

printf '\n%s\n%s\n' \
  "$marker" \
  "$binding" \
  >>"$binding_file"

echo "installed $chord keybinding"
