#!/bin/bash
# ============================================================
# install.sh - Instalador Guiado Auto Script VPN
# ============================================================
# Este script guia você passo a passo na instalação de todos
# os serviços VPN, com verificação de erros, retry automático
# e download de arquivos faltantes.
# ============================================================
# Uso:
#   bash install.sh           # Modo interativo
#   bash install.sh --all     # Instala tudo sem perguntar
#   bash install.sh --help    # Ajuda
# ============================================================

set -o pipefail

# ----------------------------------------------------------
# Inicialização
# ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DATE="$(date '+%Y-%m-%d_%H-%M-%S')"
export LOG_FILE="/root/install-vpn-${INSTALL_DATE}.log"

# Carrega bibliotecas
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
    echo -e "${RED}ERRO: lib/colors.sh não encontrado${NC}"
}
source "${SCRIPT_DIR}/lib/logger.sh" 2>/dev/null || {
    echo -e "${RED}ERRO: lib/logger.sh não encontrado${NC}"
    exit 1
}
source "${SCRIPT_DIR}/lib/checker.sh" 2>/dev/null || {
    log_error "lib/checker.sh não encontrado. Abortando."
    exit 1
}
source "${SCRIPT_DIR}/lib/downloader.sh" 2>/dev/null || {
    log_error "lib/downloader.sh não encontrado. Abortando."
    exit 1
}

# Carrega configurações
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
else
    log_warn "config.env não encontrado, usando configurações padrão"
fi
# ----------------------------------------------------------
# Variáveis globais
# ----------------------------------------------------------
INSTALL_MODE="interactive"  # interactive | automatic
FAILED_SERVICES=()
SKIPPED_SERVICES=()
INSTALLED_SERVICES=()
CURRENT_SERVICE=""
CURRENT_STEP=0
TOTAL_STEPS=0

# Repositórios (usa config.env se disponível, senão defaults)
GIT_BASE="${GIT_BASE:-raw.githubusercontent.com/faizalsalato/ssh/main}"
SSH_REPO="${SSH_REPO:-${GIT_BASE}/ssh}"
XRAY_REPO="${XRAY_REPO:-${GIT_BASE}/xray}"
SSTP_REPO="${SSTP_REPO:-${GIT_BASE}/sstp}"
SSR_REPO="${SSR_REPO:-${GIT_BASE}/ssr}"
SHADOWSOCKS_REPO="${SHADOWSOCKS_REPO:-${GIT_BASE}/shadowsocks}"
WIREGUARD_REPO="${WIREGUARD_REPO:-${GIT_BASE}/wireguard}"
IPSEC_REPO="${IPSEC_REPO:-${GIT_BASE}/ipsec}"
BACKUP_REPO="${BACKUP_REPO:-${GIT_BASE}/backup}"
WEBSOCKET_REPO="${WEBSOCKET_REPO:-${GIT_BASE}/websocket}"
OHP_REPO="${OHP_REPO:-${GIT_BASE}/ohp}"
API_REPO="${API_REPO:-${GIT_BASE}/api}"
GRPC_REPO="${GRPC_REPO:-${GIT_BASE}/grpc}"

# ----------------------------------------------------------
# Funções do instalador
# ----------------------------------------------------------

ask_install() {
    local service="$1"
    if [ "$INSTALL_MODE" == "automatic" ]; then
        return 0
    fi
    echo -e "\n${CYAN}Instalar ${service}? [S/n/q]${NC}"
    read -p "> " sn
    case "${sn,,}" in
        s|"") return 0 ;;
        n)     return 1 ;;
        q)     log_info "Cancelado."; show_summary; exit 0 ;;
        *)     return 0 ;;
    esac
}

handle_error() {
    local service="$1"
    local exit_code="$2"
    local error_msg="${3:-Erro desconhecido}"
    log_fail "ERRO: $service (código $exit_code)"
    log_error "$error_msg"
    echo -e "${ORANGE}[T]entar novamente  [P]ular  [A]bortar${NC}"
    read -p "> " action
    case "${action,,}" in
        t) return 1 ;;
        p) SKIPPED_SERVICES+=("$service"); return 0 ;;
        a) show_summary; exit 1 ;;
        *) return 1 ;;
    esac
}

install_service() {
    local service="$1"
    local script_url="$2"
    local script_name="$3"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log_separator "[$CURRENT_STEP/$TOTAL_STEPS] Instalando: $service"
    local retry=0
    while [ $retry -le 2 ]; do
        local tmp="/tmp/${script_name}"
        if ! download_file "$script_url" "$tmp" "$script_name"; then
            if [ $retry -lt 2 ]; then
                retry=$((retry + 1))
                sleep 3
                continue
            fi
            handle_error "$service" 1 "Falha no download"
            return 1
        fi
        chmod +x "$tmp"
        local err_out
        err_out=$(bash "$tmp" 2>&1)
        local ec=$?
        rm -f "$tmp"
        if [ $ec -eq 0 ]; then
            log_ok "$service instalado!"
            INSTALLED_SERVICES+=("$service")
            return 0
        fi
        log_fail "$service falhou (código $ec)"
        local last=$(echo "$err_out" | grep -i "error\|fail\|not found" | tail -3)
        [ -n "$last" ] && echo -e "${RED}$last${NC}"
        if [ $retry -lt 2 ]; then
            retry=$((retry + 1))
            sleep 3
            continue
        fi
        handle_error "$service" "$ec" "${last:-Ver log}"
        return 1
    done
}

save_local() {
    local url="$1"
    local dest_dir="$2"
    mkdir -p "$dest_dir" 2>/dev/null
    download_file "$url" "${dest_dir}/$(basename "$url")" "Salvando: $(basename "$url")"
}
# ----------------------------------------------------------
# Resumo final
# ----------------------------------------------------------
show_summary() {
    log_separator "RESUMO DA INSTALAÇÃO" "█"
    echo -e "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "Log: ${LOG_FILE}"
    if [ ${#INSTALLED_SERVICES[@]} -gt 0 ]; then
        echo -e "\n${GREEN_BOLD}✓ Instalados (${#INSTALLED_SERVICES[@]}):${NC}"
        for s in "${INSTALLED_SERVICES[@]}"; do echo -e "  ${GREEN}✔${NC} $s"; done
    fi
    if [ ${#SKIPPED_SERVICES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW_BOLD}⚠ Pulados (${#SKIPPED_SERVICES[@]}):${NC}"
        for s in "${SKIPPED_SERVICES[@]}"; do echo -e "  ${ORANGE}→${NC} $s"; done
    fi
    if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
        echo -e "\n${RED_BOLD}✗ Falharam (${#FAILED_SERVICES[@]}):${NC}"
        for s in "${FAILED_SERVICES[@]}"; do echo -e "  ${RED}✘${NC} $s"; done
    fi
    echo -e "\n${CYAN_BOLD}Digite 'menu' para o painel de controle.${NC}"
}

show_help() {
    echo "INSTALADOR GUIADO - Auto Script VPN"
    echo "Uso: bash install.sh [--all] [--help]"
    echo "  --all    Instala tudo automaticamente"
    echo "  --help   Mostra esta ajuda"
}

# ----------------------------------------------------------
# MAIN
# ----------------------------------------------------------
main() {
    case "${1:-}" in
        --all|-a) INSTALL_MODE="automatic" ;;
        --help|-h) show_help; exit 0 ;;
    esac

    log_banner
    echo -e "Modo: $([ "$INSTALL_MODE" == "automatic" ] && echo "Automático" || echo "Interativo")"

    if ! run_all_checks; then exit 1; fi

    # Atualização
    if ask_install "Atualização do Sistema (recomendado)"; then
        log_separator "[1] Atualizando sistema"
        apt update -y && apt upgrade -y
        log_ok "Sistema atualizado"
    else
        SKIPPED_SERVICES+=("Atualização")
    fi

    # Pacotes
    log_separator "[2] Pacotes essenciais"
    apt install -y bzip2 gzip coreutils screen curl wget unzip net-tools jq git dos2unix nano make cmake build-essential fail2ban vnstat neofetch bc htop iftop lsof rsyslog >/dev/null 2>&1
    log_ok "Pacotes instalados"

    # IPv6
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

    TOTAL_STEPS=13
    CURRENT_STEP=2

    # Serviços
    ask_install "Host/Domínio" && install_service "Host" "https://${SSH_REPO}/slhost.sh" "slhost.sh" || SKIPPED_SERVICES+=("Host")
    ask_install "SSH + OpenVPN" && install_service "SSH-OVPN" "https://${SSH_REPO}/ssh-vpn.sh" "ssh-vpn.sh" || SKIPPED_SERVICES+=("SSH-OVPN")
    ask_install "Xray Core" && install_service "Xray" "https://${XRAY_REPO}/ins-xray.sh" "ins-xray.sh" || SKIPPED_SERVICES+=("Xray")
    ask_install "WebSocket SSH" && install_service "WebSocket" "https://${WEBSOCKET_REPO}/edu.sh" "edu.sh" || SKIPPED_SERVICES+=("WebSocket")
    ask_install "SSTP VPN" && install_service "SSTP" "https://${SSTP_REPO}/sstp.sh" "sstp.sh" || SKIPPED_SERVICES+=("SSTP")
    ask_install "Shadowsocks" && install_service "Shadowsocks" "https://${SHADOWSOCKS_REPO}/sodosok.sh" "sodosok.sh" || SKIPPED_SERVICES+=("Shadowsocks")
    ask_install "SSR" && install_service "SSR" "https://${SSR_REPO}/ssr.sh" "ssr.sh" || SKIPPED_SERVICES+=("SSR")
    ask_install "WireGuard" && install_service "WireGuard" "https://${WIREGUARD_REPO}/wg.sh" "wg.sh" || SKIPPED_SERVICES+=("WireGuard")
    ask_install "L2TP/IPSec" && install_service "L2TP-IPSEC" "https://${IPSEC_REPO}/ipsec.sh" "ipsec.sh" || SKIPPED_SERVICES+=("L2TP-IPSEC")
    ask_install "OHP Server" && install_service "OHP" "https://${OHP_REPO}/ohp.sh" "ohp.sh" || SKIPPED_SERVICES+=("OHP")
    ask_install "SlowDNS" && install_service "SlowDNS" "https://raw.githubusercontent.com/leitura/slowdns/main/install" "install-slowdns.sh" || SKIPPED_SERVICES+=("SlowDNS")
    ask_install "XRAY GRPC" && install_service "GRPC" "https://${GRPC_REPO}/xray-grpc.sh" "xray-grpc.sh" || SKIPPED_SERVICES+=("GRPC")
    ask_install "Backup Automático" && install_service "Backup" "https://${BACKUP_REPO}/set-br.sh" "set-br.sh" || SKIPPED_SERVICES+=("Backup")

    # API
    if ask_install "API Node.js (gerenciamento remoto)"; then
        log_info "Instalando API..."
        if download_file "https://${API_REPO}/install.sh" "/tmp/api-install.sh" "api-install.sh"; then
            chmod +x /tmp/api-install.sh
            API_KEY="${API_KEY:-sakr}" bash /tmp/api-install.sh && INSTALLED_SERVICES+=("API") || FAILED_SERVICES+=("API")
            rm -f /tmp/api-install.sh
        fi
    else
        SKIPPED_SERVICES+=("API")
    fi

    # Finalização
    log_separator "FINALIZANDO"
    echo "2.0" > /home/ver 2>/dev/null
    history -c 2>/dev/null

    log_info "Salvando scripts essenciais localmente..."
    mkdir -p /root/vpn-scripts 2>/dev/null
    save_local "https://${SSH_REPO}/menu.sh" "/root/vpn-scripts"
    save_local "https://${SSH_REPO}/addssh.sh" "/root/vpn-scripts"
    save_local "https://${SSH_REPO}/delssh.sh" "/root/vpn-scripts"
    save_local "https://${SSH_REPO}/renewssh.sh" "/root/vpn-scripts"

    show_summary

    echo ""
    ask_install "Reiniciar servidor agora (recomendado)" && { log_info "Reiniciando em 5s..."; sleep 5; reboot; } || log_info "Reinicie manualmente: reboot"
}

main "$@"