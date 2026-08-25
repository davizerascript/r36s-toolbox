#!/bin/bash
# R36S Toolbox — funções compartilhadas
# Compatível com Bash 4+ e executável em userspace Linux do dArkOS/ArkOS.

TB_ROOT="${R36S_TOOLBOX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TB_STATE_DIR="${R36S_TOOLBOX_STATE_DIR:-/roms/tools/r36s-toolbox/state}"
TB_REPORT_DIR="${R36S_TOOLBOX_REPORT_DIR:-/roms/tools/r36s-toolbox/reports}"
TB_BACKUP_DIR="${R36S_TOOLBOX_BACKUP_DIR:-/roms/tools/r36s-toolbox/backups}"
TB_CACHE_DIR="${R36S_TOOLBOX_CACHE_DIR:-/roms/tools/r36s-toolbox/cache}"
TB_LOG="${R36S_TOOLBOX_LOG:-/roms/tools/r36s-toolbox/toolbox.log}"
TB_RUNTIME_DIR="${R36S_TOOLBOX_RUNTIME_DIR:-/tmp/r36s-toolbox}"
TB_TTY="${R36S_TOOLBOX_TTY:-/dev/tty1}"

# Em um computador de testes, permite substituir /roms por uma árvore mock.
TB_ROM_ROOT="${R36S_TOOLBOX_ROM_ROOT:-/roms}"
TB_HOME="${R36S_TOOLBOX_HOME:-${HOME:-/home/ark}}"
export TB_HOME

mkdir -p "$TB_STATE_DIR" "$TB_REPORT_DIR" "$TB_BACKUP_DIR" "$TB_CACHE_DIR" "$TB_RUNTIME_DIR" 2>/dev/null || true

has_cmd() { command -v "$1" >/dev/null 2>&1; }

log_msg() {
  local level="$1"; shift
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
  printf '%s\n' "$line" >> "$TB_LOG" 2>/dev/null || true
}

info_msg() { log_msg INFO "$*"; }
warn_msg() { log_msg WARN "$*"; }
error_msg() { log_msg ERROR "$*"; }

# Executa um comando privilegiado somente se já houver sudo sem senha ou se o processo for root.
as_root() {
  if [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]; then
    "$@"
  elif has_cmd sudo && sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
  else
    return 126
  fi
}

# Escreve sysfs sem pedir senha de forma interativa e sem montar shell com dados do usuário.
sys_write() {
  local target="$1" value="$2"
  [ -e "$target" ] || return 2
  if [ -w "$target" ]; then
    printf '%s' "$value" > "$target" 2>/dev/null
  else
    as_root sh -c 'printf "%s" "$1" > "$2"' sh "$value" "$target" 2>/dev/null
  fi
}

read_value() {
  local file="$1" fallback="${2:-N/A}"
  if [ -r "$file" ]; then
    tr -d '\000\r\n' < "$file" 2>/dev/null || printf '%s' "$fallback"
  else
    printf '%s' "$fallback"
  fi
}

read_first_matching() {
  local path value
  for path in "$@"; do
    if [ -r "$path" ]; then
      value="$(read_value "$path" '')"
      [ -n "$value" ] && { printf '%s' "$value"; return 0; }
    fi
  done
  printf 'N/A'
}

human_kb() {
  local kb="${1:-0}"
  case "$kb" in
    ''|*[!0-9]*) printf 'N/A'; return ;;
  esac
  if [ "$kb" -ge 1048576 ]; then
    awk -v n="$kb" 'BEGIN {printf "%.1f GiB", n/1048576}'
  elif [ "$kb" -ge 1024 ]; then
    awk -v n="$kb" 'BEGIN {printf "%.1f MiB", n/1024}'
  else
    printf '%s KiB' "$kb"
  fi
}

human_bytes() {
  local bytes="${1:-0}"
  case "$bytes" in
    ''|*[!0-9]*) printf 'N/A'; return ;;
  esac
  if [ "$bytes" -ge 1073741824 ]; then
    awk -v n="$bytes" 'BEGIN {printf "%.1f GiB", n/1073741824}'
  elif [ "$bytes" -ge 1048576 ]; then
    awk -v n="$bytes" 'BEGIN {printf "%.1f MiB", n/1048576}'
  elif [ "$bytes" -ge 1024 ]; then
    awk -v n="$bytes" 'BEGIN {printf "%.1f KiB", n/1024}'
  else
    printf '%s B' "$bytes"
  fi
}

percent_bar() {
  local value="${1:-0}" width="${2:-20}" filled i
  case "$value" in ''|*[!0-9]*) value=0 ;; esac
  [ "$value" -gt 100 ] && value=100
  filled=$((value * width / 100))
  printf '['
  i=0
  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then printf '#'; else printf '.'; fi
    i=$((i + 1))
  done
  printf '] %s%%' "$value"
}

find_tty() {
  if [ -c "$TB_TTY" ]; then printf '%s' "$TB_TTY"; return; fi
  if [ -c /dev/tty1 ]; then printf '/dev/tty1'; return; fi
  if [ -c /dev/tty0 ]; then printf '/dev/tty0'; return; fi
  printf '/dev/null'
}

setup_display() {
  TB_TTY="$(find_tty)"
  if [ "$TB_TTY" != /dev/null ]; then
    as_root chmod 666 "$TB_TTY" >/dev/null 2>&1 || true
    printf '\033c' > "$TB_TTY" 2>/dev/null || true
    printf '\033[?25l' > "$TB_TTY" 2>/dev/null || true
  fi
  export TERM="${TERM:-linux}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null || echo 0)}"
  if [ -d "${TB_ROM_ROOT}/tools" ]; then
    mkdir -p "${TB_ROM_ROOT}/tools/r36s-toolbox" 2>/dev/null || true
  fi

  # O gptokeyb é iniciado somente se houver dialog e nenhuma instância já ativa.
  TB_GPTOKEYB_PID=""
  if [ "${R36S_TOOLBOX_EXTERNAL_GPTOKEYB:-0}" != 1 ] && has_cmd dialog; then
    local gp keys
    for gp in /opt/inttools/gptokeyb /opt/system/Tools/PortMaster/gptokeyb /usr/bin/gptokeyb; do
      [ -x "$gp" ] || continue
      for keys in /opt/inttools/keys.gptk "$TB_ROOT/assets/toolbox.gptk"; do
        [ -f "$keys" ] || continue
        if ! pgrep -f '[g]ptokeyb.*dialog' >/dev/null 2>&1; then
          as_root chmod 666 /dev/uinput >/dev/null 2>&1 || true
          export SDL_GAMECONTROLLERCONFIG_FILE="${SDL_GAMECONTROLLERCONFIG_FILE:-/opt/inttools/gamecontrollerdb.txt}"
          "$gp" -1 dialog -c "$keys" >/dev/null 2>&1 &
          TB_GPTOKEYB_PID=$!
        fi
        break
      done
      [ -n "$TB_GPTOKEYB_PID" ] && break
    done
  fi
}

cleanup_display() {
  if [ -n "${TB_GPTOKEYB_PID:-}" ]; then
    kill "$TB_GPTOKEYB_PID" 2>/dev/null || true
    wait "$TB_GPTOKEYB_PID" 2>/dev/null || true
  fi
  unset SDL_GAMECONTROLLERCONFIG_FILE 2>/dev/null || true
  if [ -c "${TB_TTY:-/dev/null}" ]; then
    printf '\033c' > "$TB_TTY" 2>/dev/null || true
    printf '\033[?25h' > "$TB_TTY" 2>/dev/null || true
  fi
}

pause_console() {
  [ "${R36S_TOOLBOX_TEST:-0}" = 1 ] && return 0
  printf '\nPressione Enter para continuar...' >&2
  read -r _ </dev/tty 2>/dev/null || true
}

show_message() {
  local title="${1:-R36S Toolbox}" text="${2:-}" height="${3:-18}" width="${4:-76}"
  if has_cmd dialog && [ -c "${TB_TTY:-/dev/null}" ]; then
    dialog --clear --title "$title" --msgbox "$text" "$height" "$width" 2>/dev/null
  else
    printf '\n=== %s ===\n%s\n' "$title" "$text"
    pause_console
  fi
}

show_file() {
  local title="${1:-Relatório}" file="$2"
  if [ "${R36S_TOOLBOX_TEST:-0}" = 1 ]; then
    [ -f "$file" ] && cat "$file" || printf 'Arquivo não encontrado: %s\n' "$file"
    return 0
  fi
  if [ ! -f "$file" ]; then
    show_message "$title" "Arquivo não encontrado:\n$file"
  elif has_cmd dialog && [ -c "${TB_TTY:-/dev/null}" ]; then
    dialog --clear --title "$title" --textbox "$file" 0 0 2>/dev/null
  else
    cat "$file"
    pause_console
  fi
}

ask_yes_no() {
  local title="${1:-Confirmar}" text="${2:-Continuar?}"
  [ "${R36S_TOOLBOX_TEST:-0}" = 1 ] && return 0
  if has_cmd dialog && [ -c "${TB_TTY:-/dev/null}" ]; then
    dialog --clear --title "$title" --yesno "$text" 12 72 2>/dev/null
    return $?
  fi
  printf '%s [s/N] ' "$text" >&2
  local answer
  read -r answer </dev/tty 2>/dev/null || return 1
  case "$answer" in s|S|sim|SIM|y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

menu_choice() {
  local title="$1" text="$2"; shift 2
  if has_cmd dialog && [ -c "${TB_TTY:-/dev/null}" ]; then
    # O redirecionamento intencional mantém a UI no tty e captura a escolha.
    # shellcheck disable=SC2069
    dialog --clear --cancel-label "Sair" --title "$title" --menu "$text" 0 0 0 "$@" 2>&1 >/dev/tty
    return $?
  fi
  printf '\n=== %s ===\n%s\n' "$title" "$text" >&2
  local index=1 label answer
  while [ "$#" -gt 1 ]; do
    label="$2"; shift 2
    printf '%s) %s\n' "$index" "$label" >&2
    index=$((index + 1))
  done
  printf 'Escolha: ' >&2
  read -r answer </dev/tty 2>/dev/null || return 1
  printf '%s' "$answer"
}

confirm_experimental() {
  if [ "${R36S_TOOLBOX_EXPERIMENTAL:-0}" != 1 ]; then
    show_message "Módulo experimental" "Este recurso está protegido.\n\nPara habilitá-lo temporariamente, defina:\nR36S_TOOLBOX_EXPERIMENTAL=1\n\nNenhuma alteração foi feita."
    return 1
  fi
  ask_yes_no "Confirmação experimental" "$1"
}

backup_state_file() {
  local source_file="$1" destination="$2"
  [ -f "$source_file" ] || return 0
  mkdir -p "$(dirname "$destination")" 2>/dev/null || true
  cp -p "$source_file" "$destination" 2>/dev/null || true
}

safe_name() {
  printf '%s' "$1" | tr -cs '[:alnum:]_.-' '_'
}

# Compatibilidade com ambientes antigos: não depende de readarray/mapfile.
list_cpufreq_policies() {
  local p found=0
  for p in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$p" ] || continue
    printf '%s\n' "$p"
    found=1
  done
  if [ "$found" -eq 0 ] && [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    printf '/sys/devices/system/cpu/cpu0/cpufreq\n'
  fi
}

list_battery_paths() {
  local p type
  for p in /sys/class/power_supply/*; do
    [ -d "$p" ] || continue
    type="$(read_value "$p/type" '')"
    case "$(basename "$p"):$type" in
      battery:*|*:Battery|*:battery) printf '%s\n' "$p" ;;
    esac
  done
}

# Carrega o control.txt do PortMaster sem obrigar a existência de um caminho único.
locate_portmaster() {
  local candidate
  for candidate in \
    /opt/system/Tools/PortMaster \
    /opt/tools/PortMaster \
    "${TB_ROM_ROOT}/roms/ports/PortMaster" \
    "${TB_ROM_ROOT}/ports/PortMaster" \
    /storage/roms/ports/PortMaster \
    /roms/ports/PortMaster; do
    [ -d "$candidate" ] && { printf '%s' "$candidate"; return 0; }
  done
  printf '%s' /roms/ports/PortMaster
}

PORTMASTER_DIR="$(locate_portmaster)"
if [ -f "$PORTMASTER_DIR/control.txt" ]; then
  # shellcheck disable=SC1090
  . "$PORTMASTER_DIR/control.txt"
fi

export R36S_TOOLBOX_ROOT="$TB_ROOT"
export R36S_TOOLBOX_STATE_DIR="$TB_STATE_DIR"
export R36S_TOOLBOX_REPORT_DIR="$TB_REPORT_DIR"
export R36S_TOOLBOX_BACKUP_DIR="$TB_BACKUP_DIR"
export R36S_TOOLBOX_ROM_ROOT="$TB_ROM_ROOT"
