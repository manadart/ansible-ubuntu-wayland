loadavg_1m=$(cat /proc/loadavg | awk -F ' ' '{print $1}')

mem_percent=$(free -t | awk 'FNR == 2 {printf("%.0f%"), $3/$2*100}')

swap_percent=$(free -t | awk 'FNR == 3 {printf("%.0f%"), $3/$2*100}')

batt_all=$(upower -i $(upower -e | grep BAT))

batt_percent=$(echo "$batt_all" | grep "percentage" | awk '{print $2}')

batt_status=$(echo "$batt_all" | grep "state" | awk '{print $2}')

batt_time=$(echo "$batt_all" | grep "time to" | awk '{$1=$2=$3=""; print $0}' | xargs)

kernel_ver=$(uname -r | cut -d '-' -f1)

date_fmt=$(date "+%a %F %H:%M")

echo "$loadavg_1m | $mem_percent * $swap_percent | $batt_percent - $batt_status - $batt_time | $kernel_ver | $date_fmt"
