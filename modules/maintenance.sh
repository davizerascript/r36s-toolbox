#!/bin/bash
# R36S Toolbox — manutenção conservadora
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

REPORT="$TB_REPORT_DIR/manutencao-$(date +%Y%m%d-%H%M%S).txt"

known_cache_paths() {
  printf '%s\n' \
    "$TB_CACHE_DIR" \
    "$TB_ROM_ROOT/tools/r36s-toolbox/cache" \
    "$TB_ROM_ROOT/ports/PortMaster/cache" \
    "$TB_ROM_ROOT/ports/youtube/.cache" \
    "$TB_ROM_ROOT/ports/youtube/youtube/.cache" \
    "$TB_HOME/.cache/r36s-toolbox"
}

storage_report() {
  {
    printf 'R36S TOOLBOX — ARMAZENAMENTO\n\n'
    df -h / 2>/dev/null || true
    printf '\n'
    df -h "$TB_ROM_ROOT" 2>/dev/null || true
    printf '\nMaiores arquivos em ROMs (até 20):\n'
    if [ -d "$TB_ROM_ROOT" ]; then
      find "$TB_ROM_ROOT" -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -nr | head -n20 | while IFS=$'\t' read -r size path; do
        printf '%s\t%s\n' "$(human_bytes "$size")" "$path"
      done
    else
      printf 'Diretório ROM não encontrado.\n'
    fi
    printf '\nCaches conhecidos:\n'
    local path
    while IFS= read -r path; do
      [ -e "$path" ] && du -sh "$path" 2>/dev/null || true
    done < <(known_cache_paths)
  } > "$REPORT"
}

clean_known_caches() {
  local removed=0 path bytes
  if ! ask_yes_no "Limpeza conservadora" "Serão removidos somente caches conhecidos.\n\nROMs, BIOS, saves e configurações não serão tocados.\n\nContinuar?"; then
    return 0
  fi
  while IFS= read -r path; do
    [ -d "$path" ] || continue
    # Nunca remova o diretório raiz; apenas o conteúdo conhecido dentro dele.
    case "$path" in
      "$TB_CACHE_DIR"|"$TB_ROM_ROOT/tools/r36s-toolbox/cache"|"$TB_ROM_ROOT/ports/PortMaster/cache"|"$TB_ROM_ROOT/ports/youtube/.cache"|"$TB_ROM_ROOT/ports/youtube/youtube/.cache"|"$TB_HOME/.cache/r36s-toolbox")
        bytes="$(du -s -B1 "$path" 2>/dev/null | awk '{print $1}')"
        find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
        removed=$((removed + 1))
        info_msg "Cache limpo: $path ($bytes bytes)"
        ;;
    esac
  done < <(known_cache_paths)
  show_message "Manutenção" "Caches conhecidos processados: $removed\n\nNenhum save ou ROM foi apagado."
}

reset_toolbox_state() {
  if ! ask_yes_no "Restaurar estado do Toolbox" "Isso apagará somente o estado local do Toolbox e tentará restaurar o perfil de CPU salvo.\n\nContinuar?"; then return 0; fi
  "$SCRIPT_DIR/profiles.sh" restore >/dev/null 2>&1 || true
  rm -f "$TB_STATE_DIR"/*.tmp "$TB_STATE_DIR"/*.lock "$TB_STATE_DIR"/active-profile 2>/dev/null || true
  show_message "Manutenção" "Estado local do Toolbox restaurado/limpo."
}

setup_display
trap cleanup_display EXIT INT TERM
case "${1:-menu}" in
  storage) storage_report; show_file "Armazenamento" "$REPORT" ;;
  clean) clean_known_caches ;;
  reset) reset_toolbox_state ;;
  *)
    choice="$(menu_choice "Manutenção" "Escolha uma operação:" \
      1 "Analisar armazenamento" \
      2 "Limpar caches conhecidos" \
      3 "Restaurar estado do Toolbox")" || exit 0
    case "$choice" in
      1) storage_report; show_file "Armazenamento" "$REPORT" ;;
      2) clean_known_caches ;;
      3) reset_toolbox_state ;;
    esac
    ;;
esac
