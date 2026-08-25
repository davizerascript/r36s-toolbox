#!/bin/bash
# R36S Toolbox — backup e restauração segura de saves/configurações
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

latest_backup() {
  ls -1t "$TB_BACKUP_DIR"/r36s-toolbox-*.tar.gz 2>/dev/null | head -n1
}

build_file_list() {
  local root="$TB_ROM_ROOT"
  : > "$TB_RUNTIME_DIR/backup-files.list"
  [ -d "$root" ] || return 0

  # Saves e estados: somente arquivos, sem symlink e sem atravessar o root.
  find "$root" -xdev -type f \( \
    -iname '*.sav' -o -iname '*.srm' -o -iname '*.state' -o -iname '*.state[0-9]*' \
    -o -iname '*.rtc' -o -iname '*.mcr' -o -iname '*.mcd' -o -iname '*.eep' \
    -o -iname '*.fla' -o -iname '*.hi' -o -iname '*save*.json' \
  \) -printf '%P\n' 2>/dev/null | sort -u >> "$TB_RUNTIME_DIR/backup-files.list"

  # Configurações pequenas e conhecidas do ambiente/ports.
  for path in \
    "tools/r36s-toolbox/state" \
    "ports/PortMaster/control.txt" \
    "ports/PortMaster/gamecontrollerdb.txt" \
    "tools/retroarch" \
    "tools/retroarch.cfg"; do
    if [ -e "$root/$path" ]; then
      if [ -d "$root/$path" ]; then
        find "$root/$path" -xdev -type f -size -4M -printf '%P\n' 2>/dev/null | sed "s#^#$(dirname "$path")/#" >> "$TB_RUNTIME_DIR/backup-files.list"
      else
        printf '%s\n' "$path" >> "$TB_RUNTIME_DIR/backup-files.list"
      fi
    fi
  done
  sort -u -o "$TB_RUNTIME_DIR/backup-files.list" "$TB_RUNTIME_DIR/backup-files.list"
}

create_backup() {
  local stamp archive count
  build_file_list
  count="$(grep -c . "$TB_RUNTIME_DIR/backup-files.list" 2>/dev/null || printf 0)"
  if [ "$count" -eq 0 ]; then
    show_message "Backup" "Nenhum save ou arquivo de configuração conhecido foi encontrado em:\n$TB_ROM_ROOT"
    return 1
  fi
  stamp="$(date +%Y%m%d-%H%M%S)"
  archive="$TB_BACKUP_DIR/r36s-toolbox-$stamp.tar.gz"
  if ! tar --no-recursion -C "$TB_ROM_ROOT" -czf "$archive" -T "$TB_RUNTIME_DIR/backup-files.list" 2>"$TB_RUNTIME_DIR/backup-tar.err"; then
    show_message "Backup" "Falha ao criar o backup.\n\n$(cat "$TB_RUNTIME_DIR/backup-tar.err" 2>/dev/null)"
    return 1
  fi
  if tar -tzf "$archive" >/dev/null 2>&1; then
    show_message "Backup criado" "Arquivos incluídos: $count\n\nArquivo:\n$archive"
    info_msg "Backup criado: $archive ($count arquivos)"
  else
    rm -f "$archive"
    show_message "Backup" "O arquivo criado não passou na verificação de integridade."
    return 1
  fi
}

archive_is_safe() {
  local member
  while IFS= read -r member; do
    case "$member" in
      /*|../*|*/../*|..|./*) return 1 ;;
    esac
  done < <(tar -tzf "$1" 2>/dev/null)
  return 0
}

restore_backup() {
  local archive="${1:-$(latest_backup)}"
  [ -f "$archive" ] || { show_message "Restauração" "Nenhum backup encontrado."; return 1; }
  archive_is_safe "$archive" || { show_message "Restauração" "O arquivo contém caminhos inseguros e não será extraído."; return 1; }
  if ! ask_yes_no "Restaurar backup" "Isso substituirá saves/configurações existentes pelos arquivos do backup:\n\n$archive\n\nContinuar?"; then
    return 0
  fi
  if tar --no-same-owner --overwrite -C "$TB_ROM_ROOT" -xzf "$archive" 2>"$TB_RUNTIME_DIR/restore-tar.err"; then
    show_message "Restauração concluída" "O backup foi extraído em:\n$TB_ROM_ROOT"
    info_msg "Backup restaurado: $archive"
  else
    show_message "Restauração" "Falha ao restaurar.\n\n$(cat "$TB_RUNTIME_DIR/restore-tar.err" 2>/dev/null)"
    return 1
  fi
}

verify_backups() {
  local report archive
  report="$TB_REPORT_DIR/backups-$(date +%Y%m%d-%H%M%S).txt"
  {
    printf 'BACKUPS DO R36S TOOLBOX\n\n'
    for archive in "$TB_BACKUP_DIR"/r36s-toolbox-*.tar.gz; do
      [ -f "$archive" ] || continue
      if archive_is_safe "$archive" && tar -tzf "$archive" >/dev/null 2>&1; then
        printf 'OK   %s (%s)\n' "$archive" "$(human_bytes "$(stat -c %s "$archive" 2>/dev/null || echo 0)")"
      else
        printf 'ERRO %s\n' "$archive"
      fi
    done
  } > "$report"
  show_file "Verificação de backups" "$report"
}

setup_display
trap cleanup_display EXIT INT TERM
case "${1:-menu}" in
  create) create_backup ;;
  restore) restore_backup "${2:-}" ;;
  verify) verify_backups ;;
  *)
    choice="$(menu_choice "Backup" "Escolha uma operação:" \
      1 "Criar backup de saves/configurações" \
      2 "Restaurar backup mais recente" \
      3 "Verificar backups")" || exit 0
    case "$choice" in
      1) create_backup ;;
      2) restore_backup ;;
      3) verify_backups ;;
    esac
    ;;
esac
