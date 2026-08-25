#!/bin/bash
# R36S Toolbox — launcher PortMaster
# Este arquivo deve ficar em /roms/ports/r36stoolbox/R36S Toolbox.sh.

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

if [ -f "$controlfolder/control.txt" ]; then
  # shellcheck disable=SC1090
  . "$controlfolder/control.txt"
fi

# O PortMaster fornece o diretório das ROMs; o fallback cobre execução manual.
directory="${directory:-roms}"
CFW_NAME="${CFW_NAME:-ArkOS}"
DEVICE_ARCH="${DEVICE_ARCH:-aarch64}"
ESUDO="${ESUDO:-}"

if type get_controls >/dev/null 2>&1; then
  get_controls
fi

if [ -f "$controlfolder/mod_${CFW_NAME}.txt" ]; then
  # shellcheck disable=SC1090
  . "$controlfolder/mod_${CFW_NAME}.txt"
fi

GAMEDIR="${R36S_TOOLBOX_PORT_ROOT:-/${directory}/ports/r36stoolbox}"
APPDIR="$GAMEDIR/r36stoolbox"
CONFDIR="$APPDIR/conf"
EXECUTABLE="$APPDIR/bin/r36s-toolbox"
GPTK="$APPDIR/assets/toolbox.gptk"

mkdir -p "$CONFDIR/state" "$CONFDIR/reports" "$CONFDIR/backups" "$CONFDIR/cache" "$CONFDIR/runtime"
cd "$APPDIR" || exit 1

# Todo o estado do Toolbox fica dentro do próprio port.
export R36S_TOOLBOX_ROOT="$APPDIR"
export R36S_TOOLBOX_STATE_DIR="$CONFDIR/state"
export R36S_TOOLBOX_REPORT_DIR="$CONFDIR/reports"
export R36S_TOOLBOX_BACKUP_DIR="$CONFDIR/backups"
export R36S_TOOLBOX_CACHE_DIR="$CONFDIR/cache"
export R36S_TOOLBOX_RUNTIME_DIR="$CONFDIR/runtime"
export R36S_TOOLBOX_LOG="$APPDIR/log.txt"
export R36S_TOOLBOX_ROM_ROOT="${R36S_TOOLBOX_ROM_ROOT:-/${directory}}"
export R36S_TOOLBOX_TTY="${R36S_TOOLBOX_TTY:-/dev/tty1}"
export R36S_TOOLBOX_PORT_MODE=1
export R36S_TOOLBOX_EXTERNAL_GPTOKEYB=1
export XDG_CONFIG_HOME="$CONFDIR"
export XDG_DATA_HOME="$CONFDIR"
export XDG_CACHE_HOME="$CONFDIR/cache"
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
export LD_LIBRARY_PATH="$APPDIR/libs.${DEVICE_ARCH}:$APPDIR/libs:$LD_LIBRARY_PATH"

# O launcher segue o padrão dos ports: log persistente e saída visível no terminal.
: > "$APPDIR/log.txt"
exec > >(tee -a "$APPDIR/log.txt") 2>&1

# Garante que o dispositivo de entrada possa ser usado pelo gptokeyb quando necessário.
$ESUDO chmod 666 /dev/uinput >/dev/null 2>&1 || true

GPTOK_PID=""
if [ -f "$GPTK" ]; then
  if [ -n "${GPTOKEYB:-}" ]; then
    $GPTOKEYB "r36s-toolbox" -c "$GPTK" &
    GPTOK_PID=$!
  elif command -v gptokeyb >/dev/null 2>&1; then
    gptokeyb "r36s-toolbox" -c "$GPTK" &
    GPTOK_PID=$!
  fi
fi

if type pm_platform_helper >/dev/null 2>&1; then
  pm_platform_helper "$EXECUTABLE" || true
fi

if [ ! -x "$EXECUTABLE" ]; then
  printf 'Executável do R36S Toolbox não encontrado: %s\n' "$EXECUTABLE"
  status=1
else
  "$EXECUTABLE" "$@"
  status=$?
fi

# O botão de saída e a opção do menu chegam aqui; finalize só os processos criados por este port.
if [ -n "$GPTOK_PID" ]; then
  kill "$GPTOK_PID" >/dev/null 2>&1 || true
  wait "$GPTOK_PID" >/dev/null 2>&1 || true
fi

if type pm_finish >/dev/null 2>&1; then
  pm_finish || true
fi

# Em ArkOS, restaura os eventos globais caso o port tenha usado uinput.
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files oga_events.service >/dev/null 2>&1; then
  $ESUDO systemctl restart oga_events >/dev/null 2>&1 || true
fi

if [ -w /dev/tty1 ]; then
  printf '\033c' > /dev/tty1
fi
exit "$status"
