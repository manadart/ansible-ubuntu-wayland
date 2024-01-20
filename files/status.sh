mem_percent=$(free -t | awk 'FNR == 2 {printf("%.0f%"), $3/$2*100}')

batt_all=$(upower -i $(upower -e | grep BAT))

batt_percent=$(echo "$batt_all" | grep "percentage" | awk '{print $2}')

batt_status=$(echo "$batt_all" | grep "state" | awk '{print $2}')

batt_time=$(echo "$batt_all" | grep "time to" | awk '{$1=$2=$3=""; print $0}' | xargs)

kernel_version=$(uname -r | cut -d '-' -f1)

date_formatted=$(date "+%a %F %H:%M")

echo "$mem_percent | $batt_percent - $batt_status - $batt_time | $kernel_version | $date_formatted"
