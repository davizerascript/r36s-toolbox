#!/bin/bash
# R36S Toolbox — autotestes sem tocar no sistema real
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="${TMPDIR:-/tmp}/r36s-toolbox-test-$$"
export R36S_TOOLBOX_ROOT="$ROOT"
export R36S_TOOLBOX_STATE_DIR="$TEST_ROOT/state"
export R36S_TOOLBOX_REPORT_DIR="$TEST_ROOT/reports"
export R36S_TOOLBOX_BACKUP_DIR="$TEST_ROOT/backups"
export R36S_TOOLBOX_CACHE_DIR="$TEST_ROOT/cache"
export R36S_TOOLBOX_RUNTIME_DIR="$TEST_ROOT/runtime"
export R36S_TOOLBOX_LOG="$TEST_ROOT/toolbox.log"
export R36S_TOOLBOX_ROM_ROOT="$TEST_ROOT/roms"
export R36S_TOOLBOX_TTY=/dev/null
export R36S_TOOLBOX_TEST=1

failures=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failures=$((failures + 1)); }

mkdir -p "$R36S_TOOLBOX_ROM_ROOT/ports/test-port" "$R36S_TOOLBOX_ROM_ROOT/tools" "$TEST_ROOT"
printf '#!/bin/bash\necho test\n' > "$R36S_TOOLBOX_ROM_ROOT/ports/test-port/test.sh"
chmod +x "$R36S_TOOLBOX_ROM_ROOT/ports/test-port/test.sh"
printf 'save data\n' > "$R36S_TOOLBOX_ROM_ROOT/ports/test-port/test.sav"

printf 'R36S TOOLBOX — AUTOTESTE\n\n'

for f in "$ROOT"/R36S\ Toolbox.sh "$ROOT"/bin/r36s-toolbox "$ROOT"/lib/common.sh "$ROOT"/modules/*.sh "$ROOT"/tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "sintaxe: $f"; else fail "sintaxe: $f"; fi
done

if grep -q 'youtube/youtube' "$ROOT/R36S Toolbox.sh"; then
  fail "launcher não deve depender do YouTube"
else
  pass "launcher independente do YouTube"
fi

PORT="$ROOT/port/r36stoolbox"
for required in "$PORT/port.json" "$PORT/README.md" "$PORT/screenshot.png" "$PORT/gameinfo.xml" "$PORT/R36S Toolbox.sh" "$PORT/r36stoolbox/bin/r36s-toolbox" "$PORT/r36stoolbox/assets/toolbox.gptk"; do
  if [ -e "$required" ]; then pass "arquivo do port: $required"; else fail "arquivo ausente no port: $required"; fi
done
if python3 -m json.tool "$PORT/port.json" >/dev/null 2>&1; then pass "port.json válido"; else fail "port.json inválido"; fi
if grep -q '0 "Sair para o menu Ports"' "$PORT/r36stoolbox/bin/r36s-toolbox"; then pass "saída explícita para Ports"; else fail "saída explícita ausente"; fi
if grep -q 'get_controls' "$PORT/R36S Toolbox.sh" && grep -q 'pm_finish' "$PORT/R36S Toolbox.sh"; then pass "hooks PortMaster presentes"; else fail "hooks PortMaster ausentes"; fi
if grep -q 'R36S_TOOLBOX_EXTERNAL_GPTOKEYB=1' "$PORT/R36S Toolbox.sh" && grep -q 'R36S_TOOLBOX_EXTERNAL_GPTOKEYB' "$PORT/r36stoolbox/lib/common.sh"; then pass "gptokeyb externo sem duplicação"; else fail "proteção contra gptokeyb duplicado ausente"; fi
if grep -q '^a = enter$' "$PORT/r36stoolbox/assets/toolbox.gptk" && grep -q '^b = escape$' "$PORT/r36stoolbox/assets/toolbox.gptk" && grep -q '^up = up$' "$PORT/r36stoolbox/assets/toolbox.gptk"; then pass "mapa gptk básico válido"; else fail "mapa gptk incompleto"; fi

# Execução do launcher PortMaster contra uma árvore temporária.
PORT_RUN="$TEST_ROOT/port-run/r36stoolbox"
mkdir -p "$TEST_ROOT/port-run"
cp -a "$PORT" "$PORT_RUN"
if R36S_TOOLBOX_PORT_ROOT="$PORT_RUN" "$PORT_RUN/R36S Toolbox.sh" diagnostic >/dev/null 2>&1; then
  if find "$PORT_RUN/r36stoolbox/conf/reports" -type f -name 'diagnostico-*.txt' -size +0c 2>/dev/null | grep -q .; then pass "launcher PortMaster executa diagnóstico"; else fail "launcher não gerou relatório"; fi
else
  fail "launcher PortMaster encerrou com erro"
fi

if R36S_TOOLBOX_PORT_ROOT="$R36S_TOOLBOX_ROM_ROOT/ports" "$ROOT/modules/portcheck.sh" >/dev/null 2>&1; then
  report="$(ls -1t "$R36S_TOOLBOX_REPORT_DIR"/ports-*.txt 2>/dev/null | head -n1)"
  if [ -f "$report" ] && grep -q 'TOTAL DE SCRIPTS: 1' "$report"; then pass "verificador encontrou port mock"; else fail "verificador não gerou relatório esperado"; fi
else
  fail "verificador encerrou com erro"
fi

# Teste de segurança do backup: arquivo traversal não pode ser aceito.
mkdir -p "$R36S_TOOLBOX_BACKUP_DIR"
python3 "$ROOT/tests/make-unsafe-tar.py" "$R36S_TOOLBOX_BACKUP_DIR/r36s-toolbox-unsafe.tar.gz"
if "$ROOT/modules/backup.sh" verify >/dev/null 2>&1; then
  report="$(ls -1t "$R36S_TOOLBOX_REPORT_DIR"/backups-*.txt 2>/dev/null | head -n1)"
  if [ -f "$report" ] && grep -q 'ERRO' "$report"; then pass "backup rejeita archive inseguro"; else fail "backup não sinalizou archive inseguro"; fi
else
  fail "verificação de backup encerrou com erro"
fi

# Teste de restauração do conteúdo de um save.
printf 'conteudo original\n' > "$R36S_TOOLBOX_ROM_ROOT/ports/test-port/test.sav"
"$ROOT/modules/backup.sh" create >/dev/null 2>&1 || fail "criação de backup de restauração"
restore_archive="$(find "$R36S_TOOLBOX_BACKUP_DIR" -name '*.tar.gz' ! -name '*unsafe*' -print -quit)"
printf 'conteudo alterado\n' > "$R36S_TOOLBOX_ROM_ROOT/ports/test-port/test.sav"
"$ROOT/modules/backup.sh" restore "$restore_archive" >/dev/null 2>&1 || fail "restauração de backup"
if [ "$(cat "$R36S_TOOLBOX_ROM_ROOT/ports/test-port/test.sav")" = 'conteudo original' ]; then pass "backup restaura conteúdo"; else fail "backup não restaurou conteúdo"; fi

rm -rf "$TEST_ROOT"
printf '\nResultado: %s falha(s)\n' "$failures"
[ "$failures" -eq 0 ]
