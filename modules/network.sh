#!/bin/bash
# R36S Toolbox — diagnóstico de rede somente leitura
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

REPORT="$TB_REPORT_DIR/rede-$(date +%Y%m%d-%H%M%S).txt"

collect_network() {
  local iface ssid ip state target
  {
    printf 'R36S TOOLBOX — DIAGNÓSTICO DE REDE\n'
    printf 'Gerado em: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf '[INTERFACES]\n'
    if has_cmd ip; then
      ip -brief link 2>/dev/null || ip link 2>/dev/null
      printf '\n'
      ip -brief addr 2>/dev/null || ip -4 addr 2>/dev/null
    else
      printf 'Comando ip não disponível.\n'
    fi

    printf '\n[WIFI]\n'
    for iface in wlan0 mlan0; do
      [ -d "/sys/class/net/$iface" ] || continue
      state="$(read_value "/sys/class/net/$iface/operstate" 'unknown')"
      ssid=''
      if has_cmd iwgetid; then ssid="$(iwgetid "$iface" -r 2>/dev/null)"; fi
      [ -z "$ssid" ] && ssid="não identificado"
      printf '%s: estado=%s, SSID=%s\n' "$iface" "$state" "$ssid"
    done

    printf '\n[ROTAS E DNS]\n'
    if has_cmd ip; then ip route 2>/dev/null || true; fi
    if [ -r /etc/resolv.conf ]; then grep -E '^nameserver ' /etc/resolv.conf || true; fi

    printf '\n[ENDEREÇOS]\n'
    for iface in wlan0 mlan0 eth0 end0 usb0; do
      [ -d "/sys/class/net/$iface" ] || continue
      ip="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')"
      [ -z "$ip" ] && ip="sem IPv4"
      printf '%s: %s\n' "$iface" "$ip"
    done

    printf '\n[TESTE DE CONECTIVIDADE]\n'
    target="${R36S_TOOLBOX_PING_TARGET:-1.1.1.1}"
    if has_cmd ping; then
      ping -c 3 -W 3 "$target" 2>&1 || true
      printf '\nResumo: '
      ping -c 3 -W 3 "$target" 2>/dev/null | tail -n2 || true
    else
      printf 'ping não disponível.\n'
    fi

    printf '\n[FERRAMENTAS]\n'
    for cmd in ip iw iwgetid nmcli ping curl wget sshd smbd; do
      printf '%-8s %s\n' "$cmd" "$(has_cmd "$cmd" && echo disponível || echo ausente)"
    done
  } > "$REPORT"
}

setup_display
trap cleanup_display EXIT INT TERM
collect_network
show_file "Rede e conectividade" "$REPORT"
