#!/bin/bash
# R36S Toolbox — diagnóstico somente leitura

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Quando chamado como módulo direto, common.sh fica um nível acima.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/common.sh"

REPORT="$TB_REPORT_DIR/diagnostico-$(date +%Y%m%d-%H%M%S).txt"

first_file() {
  local p
  for p in "$@"; do
    [ -r "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

read_model() {
  local value
  value="$(read_value /proc/device-tree/model '')"
  if [ -n "$value" ]; then printf '%s' "$value"; return; fi
  value="$(read_value /sys/firmware/devicetree/base/model '')"
  [ -n "$value" ] && { printf '%s' "$value"; return; }
  printf 'Desconhecido'
}

read_cpu_model() {
  local value
  value="$(awk -F: '/model name|Processor|Hardware/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  [ -z "$value" ] && value="$(read_value /sys/devices/system/cpu/cpu0/uevent '')"
  [ -z "$value" ] && value="$(read_value /proc/device-tree/compatible '')"
  [ -n "$value" ] && printf '%s' "$value" || printf 'Desconhecido'
}

read_temp() {
  local path value label
  for path in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$path" ] || continue
    value="$(read_value "$path" '')"
    case "$value" in
      ''|*[!0-9-]*) continue ;;
    esac
    if [ "${value#-}" -gt 1000 ] 2>/dev/null; then
      awk -v n="$value" 'BEGIN {printf "%.1f C", n/1000}'
    else
      printf '%s C' "$value"
    fi
    label="$(read_value "${path%/temp}/type" '')"
    [ -n "$label" ] && printf ' (%s)' "$label"
    return
  done
  printf 'N/A'
}

read_battery() {
  local bat path capacity status voltage current health
  bat="$(list_battery_paths | head -n1)"
  [ -n "$bat" ] || { printf 'N/A'; return; }
  capacity="$(read_value "$bat/capacity" 'N/A')"
  status="$(read_value "$bat/status" 'N/A')"
  voltage="$(read_value "$bat/voltage_now" '')"
  current="$(read_value "$bat/current_now" '')"
  health="$(read_value "$bat/health" '')"
  printf '%s%%, %s' "$capacity" "$status"
  [ -n "$health" ] && printf ', saúde: %s' "$health"
  case "$voltage" in ''|*[!0-9]*) ;; *) awk -v n="$voltage" 'BEGIN {printf ", %.2f V", n/1000000}' ;; esac
  case "$current" in ''|*[!0-9-]*) ;; *) awk -v n="$current" 'BEGIN {printf ", %.0f mA", n/1000}' ;; esac
}

read_net() {
  local iface ssid ip
  iface=""
  for iface in wlan0 mlan0 eth0 end0; do
    [ -d "/sys/class/net/$iface" ] && break
  done
  [ -n "$iface" ] || { printf 'Nenhuma interface comum'; return; }
  ssid=''
  if has_cmd iwgetid; then ssid="$(iwgetid -r 2>/dev/null)"; fi
  ip="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')"
  [ -z "$ssid" ] && ssid="sem SSID detectável"
  [ -z "$ip" ] && ip="sem IPv4"
  printf '%s — SSID: %s — IPv4: %s' "$iface" "$ssid" "$ip"
}

read_display() {
  local path value max name
  for path in /sys/class/backlight/*/brightness; do
    [ -r "$path" ] || continue
    name="$(basename "$(dirname "$path")")"
    value="$(read_value "$path" 'N/A')"
    max="$(read_value "$(dirname "$path")/max_brightness" 'N/A')"
    printf '%s: %s/%s' "$name" "$value" "$max"
    return
  done
  printf 'Backlight sysfs não disponível'
}

read_gpu() {
  local gpu path cur max
  gpu="$(find /sys/devices/platform -maxdepth 1 -type d -iname '*gpu*' 2>/dev/null | head -n1)"
  [ -n "$gpu" ] || { printf 'Não detectada'; return; }
  path="$(find "$gpu" -type f -name cur_freq 2>/dev/null | head -n1)"
  cur="$(read_value "$path" '')"
  max="$(read_value "${path%cur_freq}max_freq" '')"
  if [ -n "$cur" ]; then
    awk -v c="$cur" -v m="$max" 'BEGIN {if (m != "") printf "%s — %.0f MHz (máx. %.0f MHz)", ARGV[1], c/1000000, m/1000000; else printf "%s — %.0f MHz", ARGV[1], c/1000000}' "$gpu"
  else
    printf '%s' "$gpu"
  fi
}

collect_report() {
  local model cpu cores arch kernel compatible dtb uptime mem_total mem_avail swap_total root_df roms_df p cur max min gov avail
  model="$(read_model)"
  cpu="$(read_cpu_model)"
  cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || printf 'N/A')"
  arch="$(uname -m 2>/dev/null || printf 'N/A')"
  kernel="$(uname -r 2>/dev/null || printf 'N/A')"
  compatible="$(read_value /proc/device-tree/compatible 'N/A')"
  dtb="$(find /boot -maxdepth 1 -type f -name '*.dtb' 2>/dev/null | head -n1)"
  [ -n "$dtb" ] && dtb="$(basename "$dtb")" || dtb="N/A"
  uptime="$(uptime 2>/dev/null || printf 'N/A')"
  mem_total="$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo)"
  mem_avail="$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo)"
  swap_total="$(awk '/^SwapTotal:/{print $2; exit}' /proc/meminfo)"
  root_df="$(df -h / 2>/dev/null | tail -n1 | awk '{print $3" usados de "$2" ("$5")"}')"
  roms_df="$(df -h "$TB_ROM_ROOT" 2>/dev/null | tail -n1 | awk '{print $3" usados de "$2" ("$5")"}')"

  {
    printf 'R36S TOOLBOX — RELATÓRIO DE DIAGNÓSTICO\n'
    printf 'Gerado em: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf '[DISPOSITIVO]\n'
    printf 'Modelo: %s\nArquitetura: %s\nCompatível: %s\nDTB em /boot: %s\n' "$model" "$arch" "$compatible" "$dtb"
    printf 'Hostname: %s\nKernel: %s\nUptime: %s\n\n' "$(hostname 2>/dev/null || printf N/A)" "$kernel" "$uptime"

    printf '[CPU]\nModelo: %s\nNúcleos: %s\n' "$cpu" "$cores"
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
      printf 'Políticas cpufreq:\n'
      for p in $(list_cpufreq_policies); do
        cur="$(read_value "$p/scaling_cur_freq" 'N/A')"
        max="$(read_value "$p/scaling_max_freq" 'N/A')"
        min="$(read_value "$p/scaling_min_freq" 'N/A')"
        gov="$(read_value "$p/scaling_governor" 'N/A')"
        printf '  %s: atual=%s kHz, mínimo=%s kHz, máximo=%s kHz, governor=%s\n' "$(basename "$p")" "$cur" "$min" "$max" "$gov"
        avail="$(read_value "$p/scaling_available_frequencies" '')"
        [ -n "$avail" ] && printf '    frequências expostas: %s\n' "$avail"
      done
    else
      printf 'cpufreq: não disponível\n'
    fi
    printf '\n[TEMPERATURA]\nSoC: %s\nGPU: %s\n\n' "$(read_temp)" "$(read_gpu)"

    printf '[MEMÓRIA]\nTotal: %s\nDisponível: %s\nSwap total: %s\n' "$(human_kb "${mem_total:-0}")" "$(human_kb "${mem_avail:-0}")" "$(human_kb "${swap_total:-0}")"
    printf 'Raiz: %s\nROMs: %s\n\n' "${root_df:-N/A}" "${roms_df:-N/A}"

    printf '[BATERIA]\n%s\n\n' "$(read_battery)"
    printf '[TELA]\n%s\n\n' "$(read_display)"
    printf '[REDE]\n%s\n\n' "$(read_net)"

    printf '[SOFTWARE]\nOS candidates:\n'
    for f in /etc/os-release /etc/arkos-release /etc/arkos_version /opt/arkos/version /home/ark/.config/.OS; do
      [ -r "$f" ] && printf '  %s: %s\n' "$f" "$(head -n2 "$f" 2>/dev/null | tr '\n' ' ')"
    done
    printf 'PortMaster: %s\n' "${PORTMASTER_DIR:-N/A}"
    printf 'Dialog: %s | gptokeyb: %s | mpv: %s | iwgetid: %s\n' "$(has_cmd dialog && echo sim || echo não)" "$(has_cmd gptokeyb && echo sim || echo não)" "$(has_cmd mpv && echo sim || echo não)" "$(has_cmd iwgetid && echo sim || echo não)"
  } > "$REPORT"
  printf '%s' "$REPORT"
}

setup_display
trap cleanup_display EXIT INT TERM
REPORT_PATH="$(collect_report)"
show_file "Diagnóstico R36S Toolbox" "$REPORT_PATH"
