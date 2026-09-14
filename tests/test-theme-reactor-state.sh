#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d /tmp/solar-forge-reactor.XXXXXX)"
user_themes="$test_dir/user/themes"
system_themes="$test_dir/system/themes"
current="$test_dir/current"
mkdir -p "$user_themes/nebula/backgrounds" "$system_themes/nord/backgrounds" "$current"

printf '%s\n' 'accent = "#123456"' 'magenta = "#654321"' 'background = "#101010"' >"$user_themes/nebula/colors.toml"
printf '%s\n' 'accent = "#88c0d0"' 'background = "#2e3440"' >"$system_themes/nord/colors.toml"
touch "$user_themes/nebula/backgrounds/01-neon-city.png" "$system_themes/nord/backgrounds/snow.jpg"
printf '%s\n' nebula >"$current/theme.name"
ln -s "$user_themes/nebula/backgrounds/01-neon-city.png" "$current/background"

payload=$(SOLAR_FORGE_USER_THEMES="$user_themes" SOLAR_FORGE_SYSTEM_THEMES="$system_themes" \
  SOLAR_FORGE_CURRENT_STATE="$current" "$project_dir/scripts/theme-reactor-state.sh")

jq -e '.currentTheme == "Nebula" and .wallpaperName == "Neon City"' <<<"$payload" >/dev/null
jq -e '.themes | length == 2' <<<"$payload" >/dev/null
jq -e '.themes[] | select(.id == "nebula") | .accent == "#123456" and .secondary == "#654321" and .backgroundCount == 1 and .current' <<<"$payload" >/dev/null
jq -e '.themes[] | select(.id == "nord") | .accent == "#88c0d0" and (.current | not)' <<<"$payload" >/dev/null

echo "Theme reactor state checks passed. Test files: $test_dir"
