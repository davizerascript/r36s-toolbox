#!/bin/bash
# R36S Toolbox — monitoramento e registro de telemetria
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

INTERVAL="${R36S_TOOLBOX_INTERVAL:-2}"
DURATION="${R36S_TOOLBOX_DURATION:-30}"
REPORT="$TB_REPORT_DIR/telemetria-$(date +%Y%m%d-%H%M%S).csv"

read_temp_c() {
  local p value
  for p in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$p" ] || continue
    value="$(read_value "$p" '')"
    case "$value" in ''|*[!0-9-]*) continue ;; esac
    awk -v n="$value" 'BEGIN {if (n > 1000) printf "%.1f", n/1000; else printf "%.1f", n}'
    return
  done
  printf 'NA'
}

read_battery_pct() {
  local p
  p="$(list_battery_paths | head -n1)"
  [ -n "$p" ] && read_value "$p/capacity" NA || printf 'NA'
}

read_freq_mhz() {
  local p value
  p="$(list_cpufreq_policies | head -n1)"
  value="$(read_value "$p/scaling_cur_freq" '')"
  case "$value" in ''|*[!0-9]*) printf 'NA' ;; *) awk -v n="$value" 'BEGIN {printf "%.0f", n/1000}' ;; esac
}

read_load() {
  awk '{print $1}' /proc/loadavg 2>/dev/null || printf 'NA'
}

read_mem_available_mb() {
  local value
  value="$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo)"
  [ -n "$value" ] && awk -v n="$value" 'BEGIN {printf "%.0f", n/1024}' || printf 'NA'
}

collect_once() {
  printf '%s,%s,%s,%s,%s\n' "$(date +%s)" "$(read_temp_c)" "$(read_freq_mhz)" "$(read_load)" "$(read_mem_available_mb)" >> "$REPORT"
}

run_monitor() {
  local i max_samples
  max_samples=$((DURATION / INTERVAL))
  [ "$max_samples" -lt 1 ] && max_samples=1
  printf 'epoch,temp_c,cpu_freq_mhz,load1,mem_available_mb\n' > "$REPORT"
  i=0
  while [ "$i" -lt "$max_samples" ]; do
    collect_once
    i=$((i + 1))
    sleep "$INTERVAL"
  done
}

show_summary() {
  local report="$1" max_temp avg_temp min_mem max_freq samples
  samples="$(awk 'NR>1 && $2!="NA"{n++}END{print n+0}' "$report")"
  max_temp="$(awk -F, 'NR>1 && $2!="NA" && $2>m{m=$2}END{if(n)printf "%.1f C",m;else print "N/A"}' "$report")"
  avg_temp="$(awk -F, 'NR>1 && $2!="NA"{s+=$2;n++}END{if(n)printf "%.1f C",s/n;else print "N/A"}' "$report")"
  min_mem="$(awk -F, 'NR>1 && $5!="NA" && (m==0 || $5<m){m=$5}END{if(n)printf "%s MB",m;else print "N/A"}' "$report")"
  max_freq="$(awk -F, 'NR>1 && $3!="NA" && $3>m{m=$3}END{if(n)printf "%s MHz",m;else print "N/A"}' "$report")"
  show_message "Telemetria concluída" "Amostras válidas: $samples\nTemperatura máxima: $max_temp\nTemperatura média: $avg_temp\nFrequência máxima observada: $max_freq\nMenor memória disponível: $min_mem\n\nCSV:\n$report"
}

setup_display
trap cleanup_display EXIT INT TERM
show_message "Monitor R36S" "Serão gravadas amostras a cada ${INTERVAL}s durante ${DURATION}s.\n\nO monitor é somente leitura. Para medir um jogo, inicie-o depois desta mensagem e repita o teste com o mesmo tempo." 14 76
run_monitor
show_summary "$REPORT"
