#!/bin/bash
# R36S Toolbox — verificador de ports sem execução
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

REPORT="$TB_REPORT_DIR/ports-$(date +%Y%m%d-%H%M%S).txt"
PORT_ROOT="${R36S_TOOLBOX_PORT_ROOT:-$TB_ROM_ROOT/ports}"

check_one() {
  local script="$1" dir line status binary arch
  dir="$(dirname "$script")"
  status="OK"
  printf '\n[%s]\n' "$script"
  [ -x "$script" ] || { printf 'permissão: ERRO — script não executável\n'; status="ATENÇÃO"; }
  line="$(head -n1 "$script" 2>/dev/null)"
  case "$line" in
    '#!'*) printf 'shebang: %s\n' "$line" ;;
    *) printf 'shebang: ausente\n'; status="ATENÇÃO" ;;
  esac
  if has_cmd bash && printf '%s' "$line" | grep -q bash; then
    if bash -n "$script" 2>/dev/null; then printf 'sintaxe bash: OK\n'; else printf 'sintaxe bash: ERRO\n'; status="ERRO"; fi
  fi
  if [ -f "$dir/port.json" ]; then printf 'manifest: port.json\n'; else printf 'manifest: não encontrado\n'; fi
  if [ -f "$dir/gameinfo.xml" ]; then printf 'metadados: gameinfo.xml\n'; fi
  if [ -f "$dir/screenshot.png" ] || [ -f "$dir/screenshot.jpg" ]; then printf 'imagem: encontrada\n'; else printf 'imagem: ausente\n'; fi
  for binary in "$dir"/* "$dir"/*/*; do
    [ -f "$binary" ] || continue
    [ -x "$binary" ] || continue
    case "$(basename "$binary")" in
      *.sh|*.txt|*.json|*.xml) continue ;;
    esac
    if has_cmd file; then
      arch="$(file -b "$binary" 2>/dev/null)"
      printf 'binário: %s — %s\n' "$binary" "$arch"
      case "$arch" in
        *ARM*aarch64*|*ARM*64-bit*|*AArch64*) : ;;
        *ELF*) printf '  arquitetura: verificar manualmente\n'; status="ATENÇÃO" ;;
      esac
    fi
  done
  printf 'status: %s\n' "$status"
}

run_check() {
  {
    printf 'R36S TOOLBOX — VERIFICAÇÃO DE PORTS\n'
    printf 'Diretório: %s\nGerado em: %s\n' "$PORT_ROOT" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Este relatório não executa scripts nem binários.\n'
    if [ ! -d "$PORT_ROOT" ]; then
      printf '\nDiretório de ports não encontrado.\n'
      return 0
    fi
    local count=0 script
    while IFS= read -r script; do
      count=$((count + 1))
      check_one "$script"
    done < <(find "$PORT_ROOT" -xdev -type f -iname '*.sh' -not -path '*/PortMaster/*' 2>/dev/null | sort)
    printf '\nTOTAL DE SCRIPTS: %s\n' "$count"
  } > "$REPORT"
}

setup_display
trap cleanup_display EXIT INT TERM
run_check
show_file "Verificador de ports" "$REPORT"
