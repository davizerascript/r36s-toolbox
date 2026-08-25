#!/bin/bash
# Remove somente o port R36S Toolbox.
set -u
PORTS_ROOT="${R36S_TOOLBOX_INSTALL_ROOT:-/roms/ports}"
TARGET="$PORTS_ROOT/r36stoolbox"

if [ -x "$TARGET/r36stoolbox/modules/overclock.sh" ]; then
  R36S_TOOLBOX_TTY=/dev/null R36S_TOOLBOX_TEST=1 "$TARGET/r36stoolbox/modules/overclock.sh" restore >/dev/null 2>&1 || true
fi
if [ -x "$TARGET/r36stoolbox/modules/profiles.sh" ]; then
  R36S_TOOLBOX_TTY=/dev/null R36S_TOOLBOX_TEST=1 "$TARGET/r36stoolbox/modules/profiles.sh" restore >/dev/null 2>&1 || true
fi

rm -rf "${TARGET:?}"
printf 'R36S Toolbox removido de %s.\n' "$TARGET"
