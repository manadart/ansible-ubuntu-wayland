#!/usr/bin/env bash
set -euo pipefail

uid="$(id -u)"
cpu_state="/tmp/waybar-cpu-${uid}.state"
net_state="/tmp/waybar-net-${uid}.state"

read_cpu_totals() {
  awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat
}

read_uptime_ms() {
  awk '{printf "%.0f", $1 * 1000}' /proc/uptime
}

format_mbps() {
  local kbps="$1"
  awk -v k="$kbps" 'BEGIN {printf "%.2f Mbps", k/1000}'
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
  local iface rx tx now_ms prev_iface prev_rx prev_tx prev_ms delta_ms down_kbps up_kbps
  iface="$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')"
  if [[ -z "${iface}" ]]; then
    iface="$(awk -F: '/:/{gsub(/ /, "", $1); if ($1 != "lo") {print $1; exit}}' /proc/net/dev)"
  fi
  if [[ -z "${iface}" ]]; then
    printf "N/A"
    return
  fi

  read -r rx tx < <(awk -v iface="$iface" '$1 ~ /:$/ {name=$1; sub(/:$/, "", name); if (name == iface) {print $2, $10; exit}}' /proc/net/dev)
  if [[ -z "${rx:-}" || -z "${tx:-}" ]]; then
    printf "N/A"
    return
  fi
  now_ms="$(read_uptime_ms)"
  down_kbps="0"
  up_kbps="0"

  if [[ -f "$net_state" ]]; then
    read -r prev_iface prev_rx prev_tx prev_ms < "$net_state"
    if [[ "$prev_iface" == "$iface" && "${prev_ms:-}" =~ ^[0-9]+$ ]]; then
      delta_ms=$((now_ms - prev_ms))
      if (( delta_ms > 0 )); then
        down_kbps="$(awk -v cur="$rx" -v prev="$prev_rx" -v dt="$delta_ms" 'BEGIN {
          if (cur >= prev) {
            printf "%.1f", (cur - prev) * 8 / dt
          } else {
            printf "0"
          }
        }')"
        up_kbps="$(awk -v cur="$tx" -v prev="$prev_tx" -v dt="$delta_ms" 'BEGIN {
          if (cur >= prev) {
            printf "%.1f", (cur - prev) * 8 / dt
          } else {
            printf "0"
          }
        }')"
      fi
    fi
  fi
  printf "%s %s %s %s\n" "$iface" "$rx" "$tx" "$now_ms" > "$net_state"
  printf "%s↓ %s↑" "$(format_mbps "$down_kbps")" "$(format_mbps "$up_kbps")"
}

mem_percent="$(free | awk '/^Mem:/ {printf "%.0f%%", $3/$2*100}')"
swap_percent="$(free | awk '/^Swap:/ {if ($2 > 0) {printf "%.0f%%", $3/$2*100} else {printf "0%%"}}')"
cpu_percent="$(cpu_usage)"
net_speed="$(network_usage)"
kernel_ver="$(uname -r | cut -d '-' -f1)"
date_fmt="$(date '+%a %F %H:%M')"

echo "CPU ${cpu_percent} | NET ${net_speed} | MEM ${mem_percent} * SWP ${swap_percent}  | ${kernel_ver} | ${date_fmt}"
