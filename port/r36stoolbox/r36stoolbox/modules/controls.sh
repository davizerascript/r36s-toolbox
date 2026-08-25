#!/bin/bash
# R36S Toolbox — teste de controles
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

REPORT="$TB_REPORT_DIR/controles-$(date +%Y%m%d-%H%M%S).txt"

list_input_devices() {
  {
    printf 'DISPOSITIVOS DE ENTRADA\n\n'
    if [ -r /proc/bus/input/devices ]; then
      awk '
        /^N: Name=/ {name=$0}
        /^H: Handlers=/ {print name; print $0; print ""}
      ' /proc/bus/input/devices
    else
      printf '/proc/bus/input/devices indisponível\n'
    fi
    printf '\nLINKS DE JOYSTICK\n'
    for p in /dev/input/js* /dev/input/by-path/*joystick* /dev/input/by-id/*joystick*; do
      [ -e "$p" ] || continue
      printf '%s -> %s\n' "$p" "$(readlink -f "$p" 2>/dev/null || printf '?')"
    done
    printf '\nLINKS DE EVENTOS\n'
    for p in /dev/input/event* /dev/input/by-path/*event*; do
      [ -e "$p" ] || continue
      printf '%s -> %s\n' "$p" "$(readlink -f "$p" 2>/dev/null || printf '?')"
    done
    printf '\nFERRAMENTAS\n'
    printf 'gptokeyb: %s\n' "$(has_cmd gptokeyb && echo disponível || echo ausente)"
    printf 'evtest: %s\n' "$(has_cmd evtest && echo disponível || echo ausente)"
    printf 'jstest: %s\n' "$(has_cmd jstest && echo disponível || echo ausente)"
    printf 'SDL gamecontrollerdb: %s\n' "$(read_first_matching /opt/inttools/gamecontrollerdb.txt /roms/ports/PortMaster/gamecontrollerdb.txt /usr/share/games/gamecontrollerdb.txt)"
    printf '\nCONFIGURAÇÃO SDL RECEBIDA DO PORTMASTER\n'
    if [ -n "${sdl_controllerconfig:-}" ]; then
      printf '%s\n' "$sdl_controllerconfig"
    else
      printf 'sdl_controllerconfig não carregada; control.txt/get_controls pode não estar disponível.\n'
    fi
    printf '\nMAPA GPTK DO TOOLBOX\n'
    if [ -f "$TB_ROOT/assets/toolbox.gptk" ]; then
      cat "$TB_ROOT/assets/toolbox.gptk"
    else
      printf 'toolbox.gptk não encontrado em %s/assets\n' "$TB_ROOT"
    fi
    printf '\nARQUIVO SDL CONFIGURADO\n'
    printf 'SDL_GAMECONTROLLERCONFIG_FILE=%s\n' "${SDL_GAMECONTROLLERCONFIG_FILE:-não definido}"
    printf 'SDL_GAMECONTROLLERCONFIG=%s\n' "${SDL_GAMECONTROLLERCONFIG:-não definido}"
  } > "$REPORT"
}

capture_events() {
  local device
  device=""
  for device in /dev/input/by-path/*joypad*event-joystick /dev/input/event* /dev/input/js0; do
    [ -e "$device" ] && break
  done
  [ -e "$device" ] || { printf '\nNenhum dispositivo de entrada encontrado.\n' >> "$REPORT"; return 1; }

  {
    printf '\nCAPTURA DE EVENTOS\nDispositivo: %s\n' "$device"
    printf 'Pressione botões por até 15 segundos; encerre com Ctrl+C se necessário.\n\n'
  } >> "$REPORT"

  if has_cmd evtest && [[ "$device" == *event* ]]; then
    timeout 15s evtest "$device" >> "$REPORT" 2>&1 || true
  elif has_cmd jstest && [[ "$device" == /dev/input/js* ]]; then
    timeout 15s jstest --normal "$device" >> "$REPORT" 2>&1 || true
  else
    printf 'evtest/jstest não disponível para captura.\n' >> "$REPORT"
    return 1
  fi
}

setup_display
trap cleanup_display EXIT INT TERM
list_input_devices
if ask_yes_no "Teste de controles" "Deseja capturar eventos dos botões por 15 segundos?\n\nA captura será somente leitura e ficará no relatório."; then
  capture_events || true
fi
show_file "Teste de controles" "$REPORT"
