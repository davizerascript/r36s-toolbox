#!/bin/bash
# R36S Toolbox — módulo experimental de frequência
# Regra: não inventa frequência nem altera tensão. Por padrão, somente simula.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

STATE="$TB_STATE_DIR/oc-previous.tsv"
REPORT="$TB_REPORT_DIR/overclock-$(date +%Y%m%d-%H%M%S).txt"

read_cpu_temp_raw() {
  local p v
  for p in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$p" ] || continue
    v="$(read_value "$p" '')"
    case "$v" in ''|*[!0-9-]*) continue ;; esac
    printf '%s' "$v"
    return
  done
  printf ''
}

read_cpu_temp_c() {
  local v
  v="$(read_cpu_temp_raw)"
  case "$v" in
    '') printf 'N/A' ;;
    *) awk -v n="$v" 'BEGIN {if(n>1000) printf "%.1f",n/1000;else printf "%.1f",n}' ;;
  esac
}

freq_in_list() {
  local policy="$1" target="$2" f
  for f in $(read_value "$policy/scaling_available_frequencies" ''); do
    [ "$f" = "$target" ] && return 0
  done
  return 1
}

write_state() {
  [ -f "$STATE" ] && return 0
  : > "$STATE"
  local policy
  while IFS= read -r policy; do
    [ -d "$policy" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$policy" \
      "$(read_value "$policy/scaling_governor" '')" \
      "$(read_value "$policy/scaling_min_freq" '')" \
      "$(read_value "$policy/scaling_max_freq" '')" >> "$STATE"
  done < <(list_cpufreq_policies)
  [ -s "$STATE" ] || rm -f "$STATE"
}

report_capabilities() {
  {
    printf 'R36S TOOLBOX — CPU EXPERIMENTAL\n'
    printf 'Modo: descoberta, sem alteração\n'
    printf 'Gerado em: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Temperatura atual: %s C\n\n' "$(read_cpu_temp_c)"
    local policy
    while IFS= read -r policy; do
      [ -d "$policy" ] || continue
      printf '%s\n' "$policy"
      printf '  governor: %s\n' "$(read_value "$policy/scaling_governor" N/A)"
      printf '  atual: %s kHz\n' "$(read_value "$policy/scaling_cur_freq" N/A)"
      printf '  mínimo: %s kHz\n' "$(read_value "$policy/scaling_min_freq" N/A)"
      printf '  máximo: %s kHz\n' "$(read_value "$policy/scaling_max_freq" N/A)"
      printf '  frequências expostas: %s\n' "$(read_value "$policy/scaling_available_frequencies" 'não informadas')"
      printf '  governors expostos: %s\n\n' "$(read_value "$policy/scaling_available_governors" 'não informados')"
    done < <(list_cpufreq_policies)
    printf 'O Toolbox somente considera frequências listadas em scaling_available_frequencies.\n'
    printf 'Não há alteração de voltagem, DTB, U-Boot ou kernel neste módulo.\n'
  } > "$REPORT"
}

apply_frequency() {
  local target="$1" policy min max cur raw temp_limit=70000 changed=0 failed=0
  [ -n "$target" ] || { report_capabilities; show_file "CPU experimental" "$REPORT"; return 1; }
  confirm_experimental "Esta função altera temporariamente o limite de frequência do CPU.\n\nEla só aceitará valores expostos pelo kernel, não altera voltagem e pode causar travamento.\n\nO estado anterior será salvo, mas um desligamento abrupto pode exigir restauração manual." || return 1
  raw="$(read_cpu_temp_raw)"
  if [ -n "$raw" ] && [ "$raw" -ge "$temp_limit" ] 2>/dev/null; then
    show_message "CPU experimental" "Temperatura atual muito alta: $(read_cpu_temp_c) C.\nNenhuma alteração foi feita."
    return 1
  fi
  write_state
  [ -s "$STATE" ] || { show_message "CPU experimental" "Nenhuma política cpufreq disponível."; return 1; }

  while IFS= read -r policy; do
    [ -d "$policy" ] || continue
    if ! freq_in_list "$policy" "$target"; then
      warn_msg "Frequência não exposta em $policy: $target"
      failed=1
      continue
    fi
    min="$(read_value "$policy/scaling_min_freq" '')"
    max="$(read_value "$policy/scaling_max_freq" '')"
    cur="$(read_value "$policy/scaling_cur_freq" '')"
    # Ajusta somente scaling_max_freq; nunca força min_freq nem voltage.
    if [ -n "$max" ] && [ "$target" -lt "$max" ] 2>/dev/null; then
      : # reduzir o teto é permitido
    fi
    if sys_write "$policy/scaling_max_freq" "$target"; then
      changed=$((changed + 1))
      info_msg "Limite experimental: $policy $max -> $target (atual $cur)"
    else
      failed=1
      error_msg "Falha ao escrever scaling_max_freq em $policy"
    fi
  done < <(list_cpufreq_policies)

  if [ "$changed" -gt 0 ]; then
    printf '%s\n' "$target" > "$TB_STATE_DIR/oc-active"
    show_message "CPU experimental" "Limite aplicado temporariamente: $target kHz\n\nRestaure pelo menu antes de desligar ou mude para um perfil normal.\n\nEstado salvo em:\n$STATE"
  else
    rm -f "$STATE"
    show_message "CPU experimental" "Nenhuma alteração foi aplicada. Consulte o log:\n$TB_LOG"
  fi
  return "$failed"
}

restore_frequency() {
  local policy gov min max failed=0
  [ -f "$STATE" ] || { show_message "CPU experimental" "Nenhum estado de CPU experimental salvo."; return 0; }
  while IFS=$'\t' read -r policy gov min max; do
    [ -d "$policy" ] || continue
    [ -n "$min" ] && ! sys_write "$policy/scaling_min_freq" "$min" && failed=1
    [ -n "$max" ] && ! sys_write "$policy/scaling_max_freq" "$max" && failed=1
    [ -n "$gov" ] && ! sys_write "$policy/scaling_governor" "$gov" && failed=1
  done < "$STATE"
  rm -f "$STATE" "$TB_STATE_DIR/oc-active"
  if [ "$failed" -eq 0 ]; then show_message "CPU experimental" "Estado de CPU restaurado."; else show_message "CPU experimental" "Restauração parcial. Verifique o log:\n$TB_LOG"; fi
  return "$failed"
}

interactive_menu() {
  local choice policy frequency f mhz
  policy="$(list_cpufreq_policies | head -n1)"
  choice="$(menu_choice "CPU experimental" "Nenhuma frequência ou voltagem será inventada. Escolha uma ação:" \
    1 "Mostrar capacidades" \
    2 "Aplicar frequência exposta pelo kernel" \
    3 "Restaurar estado anterior")" || return 0
  case "$choice" in
    1) report_capabilities; show_file "CPU experimental" "$REPORT" ;;
    2)
      [ -d "$policy" ] || { show_message "CPU experimental" "Nenhuma política cpufreq disponível."; return 1; }
      frequency=""
      local -a options
      options=()
      for f in $(read_value "$policy/scaling_available_frequencies" ''); do
        mhz="$(awk -v n="$f" 'BEGIN {printf "%.0f",n/1000}')"
        options+=("$f" "$f kHz (~${mhz} MHz)")
      done
      [ "${#options[@]}" -gt 0 ] || { show_message "CPU experimental" "O kernel não expôs uma lista de frequências."; return 1; }
      frequency="$(menu_choice "Escolha de frequência" "Somente valores presentes em scaling_available_frequencies:" "${options[@]}")" || return 0
      [ -n "$frequency" ] && apply_frequency "$frequency"
      ;;
    3) restore_frequency ;;
  esac
}

setup_display
trap cleanup_display EXIT INT TERM
case "${1:-menu}" in
  status|discover) report_capabilities; show_file "CPU experimental" "$REPORT" ;;
  apply) apply_frequency "${2:-}" ;;
  restore) restore_frequency ;;
  menu) interactive_menu ;;
  *) show_message "CPU experimental" "Uso:\n$0 menu\n$0 status\n$0 apply <frequência-em-kHz>\n$0 restore" ;;
esac
