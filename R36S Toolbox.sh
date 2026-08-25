#!/bin/bash
# Launcher para /roms/tools ou /roms/ports.
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$ROOT/bin/r36s-toolbox" ]; then
  TOOLBOX_ROOT="$ROOT"
elif [ -x "$ROOT/r36s-toolbox/bin/r36s-toolbox" ]; then
  TOOLBOX_ROOT="$ROOT/r36s-toolbox"
else
  printf 'R36S Toolbox não encontrado ao lado do launcher em %s\n' "$ROOT" >&2
  exit 1
fi
exec "$TOOLBOX_ROOT/bin/r36s-toolbox" "$@"
