#!/bin/bash
# R36S Toolbox — perfis reversíveis de CPU
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

STATE="$TB_STATE_DIR/cpufreq-previous.tsv"
ACTIVE="$TB_STATE_DIR/cpufreq-active"

policy_value() { read_value "$1/$2" ''; }

choose_governor() {
  local policy="$1" mode="$2" available candidate
  available="$(policy_value "$policy" scaling_available_governors)"
  case "$mode" in
    performance)
      for candidate in performance schedutil ondemand conservative powersave; do
        printf ' %s ' "$available" | grep -q " $candidate " && { printf '%s' "$candidate"; return; }
      done
      ;;
    balanced)
      for candidate in schedutil ondemand conservative performance powersave; do
        printf ' %s ' "$available" | grep -q " $candidate " && { printf '%s' "$candidate"; return; }
      done
      ;;
    battery)
      for candidate in powersave conservative schedutil ondemand; do
        printf ' %s ' "$available" | grep -q " $candidate " && { printf '%s' "$candidate"; return; }
      done
      ;;
  esac
  printf ''
}

save_original_state() {
  [ -f "$STATE" ] && return 0
  : > "$STATE"
  local policy gov min max
  while IFS= read -r policy; do
    [ -d "$policy" ] || continue
    gov="$(policy_value "$policy" scaling_governor)"
    min="$(policy_value "$policy" scaling_min_freq)"
    max="$(policy_value "$policy" scaling_max_freq)"
    printf '%s\t%s\t%s\t%s\n' "$policy" "$gov" "$min" "$max" >> "$STATE"
  done < <(list_cpufreq_policies)
  [ -s "$STATE" ] || rm -f "$STATE"
}

apply_profile() {
  local mode="$1" label="$2" policy governor changed=0 failed=0
  [ -n "$mode" ] || return 1
  while IFS= read -r policy; do
    [ -d "$policy" ] || continue
    governor="$(choose_governor "$policy" "$mode")"
    if [ -z "$governor" ]; then
      warn_msg "Nenhum governor adequado em $policy"
      failed=1
      continue
    fi
    if [ "$(policy_value "$policy" scaling_governor)" = "$governor" ]; then
      continue
    fi
    if sys_write "$policy/scaling_governor" "$governor"; then
      changed=$((changed + 1))
      info_msg "Perfil $label: $policy -> $governor"
    else
      error_msg "Não foi possível alterar governor em $policy"
      failed=1
    fi
  done < <(list_cpufreq_policies)

  if [ "$changed" -gt 0 ] || [ -f "$STATE" ]; then
    printf '%s\n' "$label" > "$ACTIVE"
  fi
  return "$failed"
}

restore_profile() {
  local policy gov min max failed=0
  [ -f "$STATE" ] || { rm -f "$ACTIVE"; show_message "Perfis" "Nenhuma configuração anterior foi salva pelo Toolbox."; return 0; }
  while IFS=$'\t' read -r policy gov min max; do
    [ -d "$policy" ] || continue
    [ -n "$gov" ] && ! sys_write "$policy/scaling_governor" "$gov" && failed=1
    [ -n "$min" ] && ! sys_write "$policy/scaling_min_freq" "$min" && failed=1
    [ -n "$max" ] && ! sys_write "$policy/scaling_max_freq" "$max" && failed=1
  done < "$STATE"
  rm -f "$STATE" "$ACTIVE"
  if [ "$failed" -eq 0 ]; then
    show_message "Perfis" "Estado anterior restaurado."
    return 0
  fi
  show_message "Perfis" "A restauração foi parcial. Consulte o log:\n$TB_LOG"
  return 1
}

status_report() {
  local report policy
  report="$TB_REPORT_DIR/cpufreq-$(date +%Y%m%d-%H%M%S).txt"
  {
    printf 'R36S TOOLBOX — CPUFREQ\n\n'
    printf 'Perfil ativo: %s\n\n' "$(read_value "$ACTIVE" 'padrão do sistema')"
    while IFS= read -r policy; do
      [ -d "$policy" ] || continue
      printf '%s\n' "$policy"
      printf '  governor atual: %s\n' "$(policy_value "$policy" scaling_governor)"
      printf '  frequência atual: %s kHz\n' "$(policy_value "$policy" scaling_cur_freq)"
      printf '  mínimo: %s kHz\n' "$(policy_value "$policy" scaling_min_freq)"
      printf '  máximo: %s kHz\n' "$(policy_value "$policy" scaling_max_freq)"
      printf '  governors: %s\n' "$(policy_value "$policy" scaling_available_governors)"
      printf '  frequências: %s\n\n' "$(policy_value "$policy" scaling_available_frequencies)"
    done < <(list_cpufreq_policies)
    [ -s "$STATE" ] && printf 'Estado salvo em: %s\n' "$STATE"
  } > "$report"
  show_file "CPU e perfis" "$report"
}

setup_display
trap cleanup_display EXIT INT TERM
case "${1:-menu}" in
  performance)
    save_original_state
    apply_profile performance "Desempenho"
    status_report
    ;;
  balanced)
    save_original_state
    apply_profile balanced "Equilibrado"
    status_report
    ;;
  battery)
    save_original_state
    apply_profile battery "Economia"
    status_report
    ;;
  restore) restore_profile ;;
  status) status_report ;;
  *)
    choice="$(menu_choice "Perfis de CPU" "Os perfis alteram somente o governor exposto pelo kernel e podem ser restaurados:" \
      1 "Desempenho" \
      2 "Equilibrado" \
      3 "Economia" \
      4 "Restaurar estado anterior" \
      5 "Ver estado atual")" || exit 0
    case "$choice" in
      1) save_original_state; apply_profile performance "Desempenho"; status_report ;;
      2) save_original_state; apply_profile balanced "Equilibrado"; status_report ;;
      3) save_original_state; apply_profile battery "Economia"; status_report ;;
      4) restore_profile ;;
      5) status_report ;;
    esac
    ;;
esac
