#!/usr/bin/env bash
set -euo pipefail

uid="$(id -u)"
cpu_state="/tmp/waybar-cpu-${uid}.state"
net_state="/tmp/waybar-net-${uid}.state"

read_cpu_totals() {
  awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat
}

format_rate() {
  local bytes="$1"
  if (( bytes < 1024 )); then
    printf "%dB/s" "$bytes"
  elif (( bytes < 1024 * 1024 )); then
    awk -v b="$bytes" 'BEGIN {printf "%.1fKB/s", b/1024}'
  else
    awk -v b="$bytes" 'BEGIN {printf "%.1fMB/s", b/1024/1024}'
  fi
}

cpu_usage() {
  local now_total now_idle prev_total prev_idle delta_total delta_idle usage
  read now_total now_idle < <(read_cpu_totals)
  if [[ -f "$cpu_state" ]]; then
    read -r prev_total prev_idle < "$cpu_state"
    delta_total=$((now_total - prev_total))
    delta_idle=$((now_idle - prev_idle))
    if (( delta_total > 0 )); then
      usage=$(( (100 * (delta_total - delta_idle)) / delta_total ))
    else
      usage=0
    fi
  else
    usage=0
  fi
  printf "%s %s\n" "$now_total" "$now_idle" > "$cpu_state"
  printf "%d%%" "$usage"
}

network_usage() {
  local iface rx tx prev_iface prev_rx prev_tx down up
  iface="$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')"
  if [[ -z "${iface}" ]]; then
    iface="$(awk -F: '/:/{gsub(/ /, "", $1); if ($1 != "lo") {print $1; exit}}' /proc/net/dev)"
  fi
  if [[ -z "${iface}" ]]; then
    printf "N/A"
    return
  fi

  read -r rx tx < <(awk -v iface="$iface" -F'[: ]+' '$1 == iface {print $3, $11}' /proc/net/dev)
  if [[ -f "$net_state" ]]; then
    read -r prev_iface prev_rx prev_tx < "$net_state"
    if [[ "$prev_iface" == "$iface" ]]; then
      down=$((rx - prev_rx))
      up=$((tx - prev_tx))
      if (( down < 0 )); then down=0; fi
      if (( up < 0 )); then up=0; fi
    else
      down=0
      up=0
    fi
  else
    down=0
    up=0
  fi
  printf "%s %s %s\n" "$iface" "$rx" "$tx" > "$net_state"
  printf "%s↓ %s↑" "$(format_rate "$down")" "$(format_rate "$up")"
}

mem_percent="$(free | awk '/^Mem:/ {printf "%.0f%%", $3/$2*100}')"
swap_percent="$(free | awk '/^Swap:/ {if ($2 > 0) {printf "%.0f%%", $3/$2*100} else {printf "0%%"}}')"
cpu_percent="$(cpu_usage)"
net_speed="$(network_usage)"

battery_status="N/A"
if upower -e 2>/dev/null | grep -q BAT; then
  battery_info="$(upower -i "$(upower -e | grep BAT | head -n1)")"
  battery_percent="$(echo "$battery_info" | awk '/percentage/ {print $2}')"
  battery_state="$(echo "$battery_info" | awk '/state/ {print $2}')"
  battery_time="$(echo "$battery_info" | awk -F': ' '/time to/ {print $2}' | head -n1)"
  if [[ -n "$battery_time" ]]; then
    battery_status="${battery_percent} - ${battery_state} - ${battery_time}"
  else
    battery_status="${battery_percent} - ${battery_state}"
  fi
fi

kernel_ver="$(uname -r | cut -d '-' -f1)"
date_fmt="$(date '+%a %F %H:%M')"

echo "CPU ${cpu_percent} | NET ${net_speed} | MEM ${mem_percent} * SWP ${swap_percent} | BAT ${battery_status} | ${kernel_ver} | ${date_fmt}"
