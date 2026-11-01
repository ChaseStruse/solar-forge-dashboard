#!/usr/bin/env bash
# Package and Omarchy update intelligence for the Depot module.
set -uo pipefail

version=$(omarchy version 2>/dev/null | head -1 || echo "unknown")
omarchy_status=$(omarchy update available 2>/dev/null | head -1 || echo "")
omarchy_ready=true
[[ "$omarchy_status" =~ "up to date" || -z "$omarchy_status" ]] && omarchy_ready=false

to_json() {
  awk '{ print $1 "\t" $2 "\t" $4 }' | jq -Rc 'split("\t") | {name: .[0], from: .[1], to: .[2]}' | jq -sc . 2>/dev/null || echo '[]'
}
repo=$(checkupdates 2>/dev/null | to_json)
aur=$(timeout 20s yay -Qua 2>/dev/null | to_json)

last_upgrade=$(grep -a "starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -1 | sed -E 's/^\[([^]]+)\].*/\1/')

jq -nc --arg version "$version" --arg status "$omarchy_status" --argjson ready "$omarchy_ready" \
  --argjson repo "${repo:-[]}" --argjson aur "${aur:-[]}" --arg last "$last_upgrade" \
  '{version: $version, omarchyStatus: $status, omarchyReady: $ready, repo: $repo, aur: $aur, lastUpgrade: $last}'
