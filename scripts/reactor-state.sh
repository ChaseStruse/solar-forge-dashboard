#!/usr/bin/env bash
# Thermal, fan, GPU, and power-profile telemetry for the Reactor module.
set -uo pipefail

sensors_json=$(sensors -j 2>/dev/null || echo '{}')
# Flatten lm_sensors output into {chip, label, kind, value, max} readings.
readings=$(jq -c '
  [ to_entries[] | .key as $chip | .value | objects | to_entries[]
    | select(.value | type == "object") | .key as $label | .value as $f
    | $f | to_entries[]
    | select(.key | test("^(temp|fan)[0-9]+_input$"))
    | (.key | capture("^(?<kind>temp|fan)(?<n>[0-9]+)_input$")) as $k
    | { chip: ($chip | sub("-.*$"; "")), label: $label, kind: $k.kind, value: .value,
        max: ($f[$k.kind + $k.n + "_max"] // $f[$k.kind + $k.n + "_crit"] // null) } ]
' <<<"$sensors_json" 2>/dev/null || echo '[]')

gpu='null'
if command -v nvidia-smi >/dev/null 2>&1; then
  line=$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,power.draw,clocks.gr --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
  if [[ -n "$line" ]]; then
    IFS=, read -r g_name g_temp g_util g_power g_clock <<<"$line"
    gpu=$(jq -nc --arg name "${g_name## }" --arg temp "${g_temp// /}" --arg util "${g_util// /}" \
      --arg power "${g_power// /}" --arg clock "${g_clock// /}" \
      '{name: $name, temp: ($temp | tonumber? // -1), util: ($util | tonumber? // -1),
        power: ($power | tonumber? // -1), clock: ($clock | tonumber? // -1)}')
  fi
fi

profile=$(powerprofilesctl get 2>/dev/null || echo "unknown")
profiles=$(powerprofilesctl list 2>/dev/null | sed -nE 's/^[* ]+([a-z-]+):$/\1/p' | jq -R . | jq -sc . 2>/dev/null || echo '[]')
[[ "$profiles" == "[]" ]] && profiles='["power-saver","balanced","performance"]'

jq -nc --argjson readings "$readings" --argjson gpu "$gpu" --arg profile "$profile" --argjson profiles "$profiles" \
  '{readings: $readings, gpu: $gpu, profile: $profile, profiles: $profiles}'
