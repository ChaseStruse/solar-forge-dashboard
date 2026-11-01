#!/usr/bin/env bash
# Wi-Fi, Bluetooth, and audio state for the Comms module.
set -uo pipefail

# nmcli -t escapes literal colons as "\:"; swap them out before splitting.
split_nmcli() {
  sed 's/\\:/\x1f/g' | awk -F: -v OFS='\t' '{ for (i = 1; i <= NF; i++) gsub(/\x1f/, ":", $i); $1 = $1; print }'
}

wifi_radio=$(nmcli radio wifi 2>/dev/null || echo "unknown")
known=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | split_nmcli | awk -F'\t' '$2 ~ /wireless/ { print $1 }' | jq -R . | jq -sc . 2>/dev/null || echo '[]')
networks=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | split_nmcli \
  | jq -Rc --argjson known "$known" 'split("\t") | select(.[1] != "")
      | { active: (.[0] == "*"), ssid: .[1], signal: (.[2] | tonumber? // 0), secure: (.[3] != "" and .[3] != "--"),
          known: (.[1] as $s | $known | index($s) != null) }' \
  | jq -sc 'group_by(.ssid) | map(max_by(.signal) + {active: (map(.active) | any)}) | sort_by(-(if .active then 1000 else 0 end) - .signal) | .[:12]' 2>/dev/null || echo '[]')

bt_powered=false
bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && bt_powered=true
devices='[]'
if [[ "$bt_powered" == true ]]; then
  devices=$(bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
      connected=false
      bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && connected=true
      jq -nc --arg mac "$mac" --arg name "$name" --argjson connected "$connected" '{mac: $mac, name: $name, connected: $connected}'
    done | jq -sc . 2>/dev/null || echo '[]')
fi

default_sink=$(pactl get-default-sink 2>/dev/null || echo "")
sinks=$(pactl -f json list sinks 2>/dev/null | jq -c --arg def "$default_sink" '
  map({ name: .name, description: (.description // .name), nodeId: (.properties["object.id"] // ""),
        mute: (.mute // false),
        volume: ((.volume | to_entries | map(.value.value_percent | sub("%"; "") | tonumber) | add) / ((.volume | length) | if . == 0 then 1 else . end) | floor),
        isDefault: (.name == $def) })' 2>/dev/null || echo '[]')

jq -nc --arg radio "$wifi_radio" --argjson networks "$networks" --argjson btPowered "$bt_powered" \
  --argjson devices "$devices" --argjson sinks "$sinks" \
  '{wifiRadio: ($radio == "enabled"), networks: $networks, bluetoothPowered: $btPowered, devices: $devices, sinks: $sinks}'
