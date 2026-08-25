#!/bin/bash
# Instala o R36S Toolbox como port em /roms/ports por padrão.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORTS_ROOT="${R36S_TOOLBOX_INSTALL_ROOT:-/roms/ports}"
TARGET="$PORTS_ROOT/r36stoolbox"
SOURCE="$ROOT/port/r36stoolbox"

[ -d "$SOURCE" ] || {
  printf 'Estrutura do port não encontrada: %s\n' "$SOURCE" >&2
  exit 1
}

mkdir -p "$PORTS_ROOT" || {
  printf 'Não foi possível criar %s. Execute com permissões adequadas.\n' "$PORTS_ROOT" >&2
  exit 1
}

rm -rf "${TARGET:?}"
cp -a "$SOURCE" "$TARGET"
chmod +x "$TARGET/R36S Toolbox.sh" "$TARGET/r36stoolbox/bin/r36s-toolbox" "$TARGET/r36stoolbox/lib/common.sh" "$TARGET/r36stoolbox/modules"/*.sh

printf 'R36S Toolbox instalado como port em:\n%s\n\nLauncher:\n%s/R36S Toolbox.sh\n\nReinicie ou atualize a lista da coleção Ports no EmulationStation.\n' "$TARGET" "$TARGET"
printf 'Teste direto: "%s/R36S Toolbox.sh" diagnostic\n' "$TARGET"
