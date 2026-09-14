#!/usr/bin/env bash
set -euo pipefail

read_cpu() {
  awk '/^cpu / { idle=$5+$6; total=0; for (i=2; i<=NF; i++) total+=$i; print idle, total; exit }' /proc/stat
}

read -r idle_a total_a < <(read_cpu)
sleep 0.12
read -r idle_b total_b < <(read_cpu)
delta_total=$((total_b - total_a))
delta_idle=$((idle_b - idle_a))
cpu_percent=0
(( delta_total > 0 )) && cpu_percent=$(((100 * (delta_total - delta_idle) + delta_total / 2) / delta_total))

read -r memory_total memory_available < <(awk '
  /^MemTotal:/ { total=$2 }
  /^MemAvailable:/ { available=$2 }
  END { print total+0, available+0 }
' /proc/meminfo)
memory_percent=0
(( memory_total > 0 )) && memory_percent=$(((100 * (memory_total - memory_available)) / memory_total))

disk_percent=$(df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5+0 }')

gpu_name=$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ { print $2; exit }')
gpu_name=${gpu_name:-GPU}
gpu_percent=-1
gpu_temperature=-1
if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_line=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
  if [[ "$gpu_line" =~ ^[^,]+,[[:space:]]*[0-9]+,[[:space:]]*[0-9]+$ ]]; then
    IFS=, read -r gpu_name gpu_percent gpu_temperature <<<"$gpu_line"
    gpu_name=${gpu_name## }
    gpu_percent=${gpu_percent//[[:space:]]/}
    gpu_temperature=${gpu_temperature//[[:space:]]/}
  else
    busy_file=$(find /sys/class/drm/card*/device -maxdepth 1 -name gpu_busy_percent -print -quit 2>/dev/null || true)
    [[ -n "$busy_file" ]] && gpu_percent=$(cat "$busy_file" 2>/dev/null || echo -1)
  fi
else
  busy_file=$(find /sys/class/drm/card*/device -maxdepth 1 -name gpu_busy_percent -print -quit 2>/dev/null || true)
  [[ -n "$busy_file" ]] && gpu_percent=$(cat "$busy_file" 2>/dev/null || echo -1)
fi

battery=$(find /sys/class/power_supply -mindepth 1 -maxdepth 1 -type l -name 'BAT*' -print -quit 2>/dev/null || true)
battery_present=false
battery_percent=-1
battery_status="Unavailable"
power_watts=-1
if [[ -n "$battery" ]]; then
  battery_present=true
  battery_percent=$(cat "$battery/capacity" 2>/dev/null || echo -1)
  battery_status=$(cat "$battery/status" 2>/dev/null || echo Unknown)
  if [[ -r "$battery/power_now" ]]; then
    power_now=$(cat "$battery/power_now" 2>/dev/null || echo 0)
    power_watts=$(awk -v power="$power_now" 'BEGIN { printf "%.2f", power / 1000000 }')
  elif [[ -r "$battery/current_now" && -r "$battery/voltage_now" ]]; then
    current_now=$(cat "$battery/current_now" 2>/dev/null || echo 0)
    voltage_now=$(cat "$battery/voltage_now" 2>/dev/null || echo 0)
    power_watts=$(awk -v current="$current_now" -v voltage="$voltage_now" 'BEGIN { printf "%.2f", (current * voltage) / 1000000000000 }')
  fi
fi

ac_online=false
while IFS= read -r supply; do
  [[ $(cat "$supply/type" 2>/dev/null || true) == "Mains" ]] || continue
  [[ $(cat "$supply/online" 2>/dev/null || echo 0) == "1" ]] && ac_online=true
done < <(find /sys/class/power_supply -mindepth 1 -maxdepth 1 -type l -print 2>/dev/null)
[[ "$battery_present" == false ]] && ac_online=true

power_profile=$(powerprofilesctl get 2>/dev/null || true)
if [[ -z "$power_profile" ]]; then
  power_profile=$(omarchy powerprofiles list --active-state 2>/dev/null | awk -F '\t' '$2 == 1 { print $1; exit }' || true)
fi
power_profile=${power_profile:-unknown}

updates_available=false
omarchy-update-available >/dev/null 2>&1 && updates_available=true

network_state=$(nmcli -t -f STATE general 2>/dev/null || true)
network_online=false
[[ "$network_state" == connected* ]] && network_online=true
network_name=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2 == "802-11-wireless" || $2 == "802-3-ethernet" { print $1; exit }' || true)
network_name=${network_name:-Offline}

bluetooth_powered=false
bluetooth_connected=false
if command -v bluetoothctl >/dev/null 2>&1; then
  bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && bluetooth_powered=true
  bluetoothctl devices Connected 2>/dev/null | grep -q '^Device ' && bluetooth_connected=true
fi

jq -cn \
  --argjson cpuPercent "$cpu_percent" --argjson memoryPercent "$memory_percent" \
  --argjson gpuPercent "$gpu_percent" --argjson gpuTemperature "$gpu_temperature" --arg gpuName "$gpu_name" \
  --argjson diskPercent "$disk_percent" --argjson batteryPresent "$battery_present" \
  --argjson batteryPercent "$battery_percent" --arg batteryStatus "$battery_status" \
  --argjson acOnline "$ac_online" --argjson powerWatts "$power_watts" --arg powerProfile "$power_profile" \
  --argjson updatesAvailable "$updates_available" --argjson networkOnline "$network_online" --arg networkName "$network_name" \
  --argjson bluetoothPowered "$bluetooth_powered" --argjson bluetoothConnected "$bluetooth_connected" \
  '{cpuPercent:$cpuPercent,memoryPercent:$memoryPercent,gpuPercent:$gpuPercent,gpuTemperature:$gpuTemperature,gpuName:$gpuName,diskPercent:$diskPercent,batteryPresent:$batteryPresent,batteryPercent:$batteryPercent,batteryStatus:$batteryStatus,acOnline:$acOnline,powerWatts:$powerWatts,powerProfile:$powerProfile,updatesAvailable:$updatesAvailable,networkOnline:$networkOnline,networkName:$networkName,bluetoothPowered:$bluetoothPowered,bluetoothConnected:$bluetoothConnected}'
