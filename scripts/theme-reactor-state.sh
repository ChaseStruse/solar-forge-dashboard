#!/usr/bin/env bash
set -euo pipefail

omarchy_path="${OMARCHY_PATH:-/usr/share/omarchy}"
user_themes="${SOLAR_FORGE_USER_THEMES:-$HOME/.config/omarchy/themes}"
system_themes="${SOLAR_FORGE_SYSTEM_THEMES:-$omarchy_path/themes}"
current_state="${SOLAR_FORGE_CURRENT_STATE:-$HOME/.local/state/omarchy/current}"

slug_to_name() {
  sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g' <<<"$1"
}

color_value() {
  local file="$1" key="$2" fallback="$3"
  [[ -f "$file" ]] || { printf '%s' "$fallback"; return; }
  awk -F= -v wanted="$key" '
    $1 ~ "^[[:space:]]*" wanted "[[:space:]]*$" {
      value=$2; gsub(/[[:space:]"]/, "", value); print value; exit
    }
  ' "$file" | sed "s/^$/$fallback/"
}

theme_color() {
  local user_file="$1" system_file="$2" key="$3" fallback="$4" value
  value=$(color_value "$user_file" "$key" "")
  [[ -n "$value" ]] || value=$(color_value "$system_file" "$key" "")
  printf '%s' "${value:-$fallback}"
}

current_slug=$(cat "$current_state/theme.name" 2>/dev/null || true)
current_name=$(slug_to_name "${current_slug:-unknown}")
wallpaper=$(readlink -f "$current_state/background" 2>/dev/null || true)
wallpaper_name="Unknown"
if [[ -n "$wallpaper" ]]; then
  wallpaper_name=$(basename -- "$wallpaper" | sed -E 's/\.[^.]+$//; s/^[0-9]+-//; s/-/ /g; s/(^| )([a-z])/\1\u\2/g')
fi

themes_json=$(
  {
    find "$user_themes" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -printf '%f\n' 2>/dev/null
    find "$system_themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
  } | sort -u | while IFS= read -r slug; do
    user_colors="$user_themes/$slug/colors.toml"
    system_colors="$system_themes/$slug/colors.toml"
    accent=$(theme_color "$user_colors" "$system_colors" accent "#7dd3fc")
    secondary=$(theme_color "$user_colors" "$system_colors" magenta "$accent")
    background=$(theme_color "$user_colors" "$system_colors" background "#10141f")
    name=$(slug_to_name "$slug")
    background_count=$(
      find -L "$user_themes/../backgrounds/$slug" "$user_themes/$slug/backgrounds" "$system_themes/$slug/backgrounds" \
        -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
        -printf '.' 2>/dev/null | wc -c
    )
    jq -cn --arg id "$slug" --arg name "$name" --arg accent "$accent" --arg secondary "$secondary" \
      --arg background "$background" --argjson backgrounds "$background_count" --arg current "$current_slug" \
      '{id:$id,name:$name,accent:$accent,secondary:$secondary,background:$background,backgroundCount:$backgrounds,current:($id == $current)}'
  done | jq -s '.'
)

jq -cn --arg currentTheme "$current_name" --arg wallpaperPath "$wallpaper" --arg wallpaperName "$wallpaper_name" \
  --argjson themes "${themes_json:-[]}" \
  '{currentTheme:$currentTheme,wallpaperPath:$wallpaperPath,wallpaperName:$wallpaperName,themes:$themes}'
