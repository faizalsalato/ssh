#!/bin/bash
# ============================================================
# install.sh - Instalador Guiado Auto Script VPN v2.2
# ============================================================
# Melhorias v2.2:
#   - OpenVPN 2.7.6 compilado com O3+native+LTO
#   - Xray config JSON limpo + sniffing ativo
#   - Download SSL porta 8445 (HTTPS)
#   - API REST 12 protocolos com PM2
#   - Menu com loop infinito + log auditoria
#   - Anti-duplicata na criação de contas
#   - Config .txt gerado automaticamente
# Melhorias v2.1:
#   - Validação de sistema antes de instalar
#   - Trap de cleanup em caso de Ctrl+C/erro
#   - Tracking correto de serviços falhados
#   - Validação de URLs antes de download
#   - Modo --dry-run para teste
#   - Retry exponencial com backoff
#   - Feedback visual melhorado
# ============================================================
# Uso:
#   bash install.sh           # Modo interativo
#   bash install.sh --all     # Instala tudo sem perguntar
#   bash install.sh --dry-run # Simula a instalação
#   bash install.sh --help    # Ajuda
# ============================================================
# Suporte: Ubuntu 18.04 / 20.04 / 22.04 / 24.04 | Debian 10/11/12
# ============================================================

set -o pipefail

# ── Detecção de OS ──
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-ubuntu}"
    OS_VERSION="${VERSION_ID:-0}"
else
    OS_ID="ubuntu"
    OS_VERSION="0"
fi

# Ajustes por versão
PHP_VERSION="7.4"
PHP_FPM_SOCK="/var/run/php/php7.4-fpm.sock"
case "${OS_VERSION:0:2}" in
    22) PHP_VERSION="8.1"; PHP_FPM_SOCK="/var/run/php/php8.1-fpm.sock" ;;
    24) PHP_VERSION="8.3"; PHP_FPM_SOCK="/var/run/php/php8.3-fpm.sock" ;;
    20|18) ;; # default 7.4
esac

echo -e "\033[0;36m[INFO]\033[0m OS: ${OS_ID} ${OS_VERSION} | PHP: ${PHP_VERSION}"

# ----------------------------------------------------------
# Inicialização
# ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
INSTALL_DATE="$(date '+%Y-%m-%d_%H-%M-%S')"
export LOG_FILE="/root/install-vpn-${INSTALL_DATE}.log"
export DRY_RUN=false
export TMP_FILES=()

# ----------------------------------------------------------
# Trap de cleanup
# ----------------------------------------------------------
cleanup_on_exit() {
    local exit_code=$?
    
    # Limpa arquivos temporários
    for f in "${TMP_FILES[@]}"; do
        [ -f "$f" ] && rm -f "$f" 2>/dev/null
    done
    
    if [ $exit_code -ne 0 ] && [ -n "${CURRENT_SERVICE:-}" ]; then
        echo -e "\n${RED_BOLD}[INTERROMPIDO]${NC} Instalação parou em: ${CURRENT_SERVICE}"
        echo -e "Log salvo em: ${LOG_FILE}"
        echo -e "Execute novamente: bash ${SCRIPT_NAME}"
    fi
    
    exit $exit_code
}

trap 'cleanup_on_exit' EXIT
trap 'echo -e "\n${RED}Ctrl+C detectado. Limpando...${NC}"; cleanup_on_exit' INT TERM

# ----------------------------------------------------------
# Carrega bibliotecas
# ----------------------------------------------------------
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; ORANGE='\033[0;33m'
    CYAN='\033[0;36m'; NC='\033[0m'
    RED_BOLD='\033[1;31m'; GREEN_BOLD='\033[1;32m'
    YELLOW_BOLD='\033[1;33m'; CYAN_BOLD='\033[1;36m'
    echo -e "${RED}AVISO: lib/colors.sh não encontrado, usando fallback${NC}"
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
    log_debug "config.env carregado"
else
    log_warn "config.env não encontrado, usando configurações padrão"
fi
# ----------------------------------------------------------
# Variáveis globais
# ----------------------------------------------------------
INSTALL_MODE="interactive"  # interactive | automatic
DRY_RUN=false               # Modo simulação
FAILED_SERVICES=()
SKIPPED_SERVICES=()
INSTALLED_SERVICES=()
CURRENT_SERVICE=""
CURRENT_STEP=0
TOTAL_STEPS=0
readonly MAX_RETRIES=3       # Máximo de tentativas por serviço
readonly RETRY_BACKOFF=5     # Segundos de espera entre retries (dobra a cada tentativa)

# Repositórios (usa config.env se disponível, senão defaults)
GIT_BASE="${GIT_BASE:-raw.githubusercontent.com/faizalsalato/ssh/main}"
SSH_REPO="${SSH_REPO:-${GIT_BASE}/ssh}"
XRAY_REPO="${XRAY_REPO:-${GIT_BASE}/xray}"
SSTP_REPO="${SSTP_REPO:-${GIT_BASE}/sstp}"
SSR_REPO="${SSR_REPO:-${GIT_BASE}/ssr}"
SHADOWSOCKS_REPO="${SHADOWSOCKS_REPO:-${GIT_BASE}/shadowsocks}"
WIREGUARD_REPO="${WIREGUARD_REPO:-${GIT_BASE}/wireguard}"
IPSEC_REPO="${IPSEC_REPO:-${GIT_BASE}/ipsec}"
BACKUP_REPO="${BACKUP_REPO:-${GIT_BASE}/ssh}"       # Fallback: usa ssh/ para set-br.sh
WEBSOCKET_REPO="${WEBSOCKET_REPO:-${GIT_BASE}/websocket}"
OHP_REPO="${OHP_REPO:-${GIT_BASE}/ohp}"
API_REPO="${API_REPO:-${GIT_BASE}/api}"
GRPC_REPO="${GRPC_REPO:-${GIT_BASE}/grpc}"

# ----------------------------------------------------------
# Funções do instalador
# ----------------------------------------------------------

# ----------------------------------------------------------
# Funções do instalador
# ----------------------------------------------------------

# Valida se uma URL está acessível antes de tentar download
validate_url() {
    local url="$1"
    local desc="${2:-URL}"

    if $DRY_RUN; then
        log_info "[DRY-RUN] Validaria: $desc ($url)"
        return 0
    fi

    local http_code
    http_code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 -L "$url" 2>/dev/null)

    case "$http_code" in
        200|301|302)
            log_debug "URL válida ($http_code): $desc"
            return 0
            ;;
        404)
            log_warn "URL não encontrada (404): $desc"
            return 1
            ;;
        403)
            log_warn "Acesso negado (403): $desc"
            return 1
            ;;
        *)
            if [ -z "$http_code" ] || [ "$http_code" == "000" ]; then
                log_warn "URL inacessível: $desc"
            else
                log_warn "URL retornou HTTP $http_code: $desc"
            fi
            return 1
            ;;
    esac
}

# Pergunta ao usuário se deve instalar um serviço
ask_install() {
    local service="$1"
    local default="${2:-S}"  # S = Sim por padrão

    if [ "$INSTALL_MODE" == "automatic" ]; then
        return 0
    fi
    
    if $DRY_RUN; then
        log_info "[DRY-RUN] Perguntaria: Instalar $service?"
        return 0
    fi

    local prompt_char
    if [ "$default" == "S" ] || [ "$default" == "s" ]; then
        prompt_char="S/n"
    else
        prompt_char="s/N"
    fi

    echo -e "\n${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Instalar ${service}? [${prompt_char}/q]${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

    while true; do
        read -p "> " sn
        sn="${sn:-${default}}"

        case "${sn,,}" in
            s|sim|yes|y)
                return 0
                ;;
            n|nao|no|não)
                return 1
                ;;
            q|quit|sair)
                log_info "Instalação cancelada pelo usuário."
                show_summary
                exit 0
                ;;
            *)
                echo -e "${ORANGE}Responda S (Sim), N (Não) ou Q (Sair)${NC}"
                ;;
        esac
    done
}

# Tratamento de erro com opções para o usuário
handle_error() {
    local service="$1"
    local exit_code="$2"
    local error_msg="${3:-Erro desconhecido}"
    
    log_fail "ERRO: $service (código $exit_code)"
    log_error "$error_msg"

    if [ "$INSTALL_MODE" == "automatic" ]; then
        FAILED_SERVICES+=("$service")
        return 2  # Código 2 = falhou e registrou
    fi

    echo -e "\n${ORANGE}[T] Tentar novamente  [P] Pular (default)  [A] Abortar instalação${NC}"

    while true; do
        read -t 30 -p "> " action || action="p"  # 30s timeout, default: pular
        case "${action,,}" in
            t|tentar|r)
                return 1  # Retry
                ;;
            p|pular|s|skip|"")
                FAILED_SERVICES+=("$service")
                return 2  # Falhou, mas segue
                ;;
            a|abortar|q|quit)
                log_info "Abortando instalação..."
                show_summary
                exit 1
                ;;
            *)
                echo -e "${ORANGE}Opções: T (Tentar), P (Pular), A (Abortar)${NC}"
                ;;
        esac
    done
}

# Instala um serviço baixando e executando o script
# Retorna: 0 = sucesso, 1 = falha, 2 = pulado pelo usuário
install_service() {
    local service="$1"
    local script_url="$2"
    local script_name="$3"
    local install_args="${4:-}"

    CURRENT_SERVICE="$service"
    CURRENT_STEP=$((CURRENT_STEP + 1))

    log_separator "[$CURRENT_STEP/$TOTAL_STEPS] Instalando: $service"
    log_info "URL: $script_url"

    # Valida a URL antes de tentar download
    if ! validate_url "https://${script_url}" "$script_name"; then
        log_warn "URL não validada para: $service"
        if ! $DRY_RUN; then
            local result
            handle_error "$service" 1 "URL inacessível: https://${script_url}"
            result=$?
            if [ $result -eq 2 ]; then
                return 2
            fi
        fi
    fi

    if $DRY_RUN; then
        log_info "[DRY-RUN] Instalaria: $service via $script_name"
        INSTALLED_SERVICES+=("$service (dry-run)")
        return 0
    fi

    # Loop de retry com backoff exponencial
    local retry=0
    local backoff=$RETRY_BACKOFF

    while [ $retry -lt $MAX_RETRIES ]; do
        local tmp="/tmp/${script_name}.$$"

        log_info "Download: $script_name (tentativa $((retry + 1))/${MAX_RETRIES})"

        if ! download_file "https://${script_url}" "$tmp" "$script_name"; then
            retry=$((retry + 1))
            if [ $retry -lt $MAX_RETRIES ]; then
                log_warn "Aguardando ${backoff}s antes da próxima tentativa..."
                sleep $backoff
                backoff=$((backoff * 2))
            fi
            continue
        fi

        # Registra para cleanup automático
        TMP_FILES+=("$tmp")

        chmod +x "$tmp"

        log_info "Executando: $script_name $install_args"

        local service_log="/tmp/${script_name}.${$}.log"

        if [ -n "$install_args" ]; then
            set +o pipefail
            DEBIAN_FRONTEND=noninteractive yes "A" 2>/dev/null | bash "$tmp" $install_args > "$service_log" 2>&1
            local ec=$?
            set -o pipefail
        else
            set +o pipefail
            DEBIAN_FRONTEND=noninteractive yes "A" 2>/dev/null | bash "$tmp" > "$service_log" 2>&1
            local ec=$?
            set -o pipefail
        fi
        local ec=$?

        # Remove do array de TMP_FILES e limpa
        for i in "${!TMP_FILES[@]}"; do
            if [ "${TMP_FILES[$i]}" == "$tmp" ]; then
                unset 'TMP_FILES[$i]'
                break
            fi
        done
        rm -f "$tmp"

        if [ $ec -eq 0 ]; then
            log_ok "$service instalado com sucesso!"
            INSTALLED_SERVICES+=("$service")
            rm -f "$service_log"
            CURRENT_SERVICE=""
            return 0
        fi

        # Falhou - mostra detalhes do erro
        log_fail "$service falhou (código $ec)"
        local last_errors
        last_errors=$(grep -iE "error|fail|not found|fatal|denied|timed out" "$service_log" 2>/dev/null | tail -5)
        if [ -n "$last_errors" ]; then
            echo -e "${RED}$last_errors${NC}"
        fi
        # Append full service log to main log for debugging
        cat "$service_log" >> "$LOG_FILE" 2>/dev/null
        rm -f "$service_log"

        retry=$((retry + 1))

        if [ $retry -lt $MAX_RETRIES ]; then
            local result
            handle_error "$service" "$ec" "${last_errors:-Ver log para detalhes}"
            result=$?
            case $result in
                1)
                    log_warn "Aguardando ${backoff}s antes da próxima tentativa..."
                    sleep $backoff
                    backoff=$((backoff * 2))
                    ;;
                2)
                    CURRENT_SERVICE=""
                    return 2
                    ;;
            esac
        else
            log_fail "$service: todas as $MAX_RETRIES tentativas falharam"
            FAILED_SERVICES+=("$service")
            CURRENT_SERVICE=""
            return 1
        fi
    done

    CURRENT_SERVICE=""
    return 1
}

# Salva scripts localmente com validação
save_local() {
    local url="$1"
    local dest_dir="$2"
    local desc="${3:-$(basename "$url")}"

    if $DRY_RUN; then
        log_info "[DRY-RUN] Salvaria: $desc em $dest_dir"
        return 0
    fi

    mkdir -p "$dest_dir" 2>/dev/null

    local dest_file="${dest_dir}/$(basename "$url")"

    if download_file "$url" "$dest_file" "Salvando: $desc"; then
        log_ok "Script salvo: $dest_file"
        return 0
    else
        log_warn "Não foi possível salvar: $desc (não crítico)"
        return 1
    fi
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
    cat << 'HELPEOF'
╔══════════════════════════════════════════════════════╗
║        AUTO SCRIPT VPN - INSTALADOR GUIADO v2.1     ║
╚══════════════════════════════════════════════════════╝

Uso: bash install.sh [OPÇÃO]

Opções:
  --all, -a     Instala todos os serviços automaticamente
                (sem confirmação interativa)
  
  --dry-run     Simula a instalação sem modificar o sistema
                (útil para testar URLs e dependências)
  
  --help, -h    Mostra esta mensagem de ajuda

Sem opções, o script roda em modo interativo, perguntando
quais serviços instalar um a um.

Serviços disponíveis:
  • Host/Domínio      • WireGuard
  • SSH + OpenVPN     • L2TP/IPSec
  • Xray Core         • OHP Server
  • WebSocket SSH     • SlowDNS
  • SSTP VPN          • XRAY GRPC
  • Shadowsocks       • Backup Automático
  • SSR               • API Node.js
HELPEOF
}

# ----------------------------------------------------------
# Helper: instala um serviço se o usuário confirmar
# ----------------------------------------------------------
install_if_asked() {
    local service_label="$1"
    local service_id="$2"
    local url="$3"
    local script_name="$4"

    if ask_install "$service_label"; then
        install_service "$service_id" "$url" "$script_name"
        local rc=$?
        if [ $rc -eq 1 ] || [ $rc -eq 2 ]; then
            # Já foi adicionado a FAILED_SERVICES dentro das funções
            :
        fi
    else
        SKIPPED_SERVICES+=("$service_id")
    fi
}

# ----------------------------------------------------------
# MAIN
# ----------------------------------------------------------
main() {
    # Processa argumentos
    for arg in "$@"; do
        case "$arg" in
            --all|-a)
                INSTALL_MODE="automatic"
                ;;
            --dry-run)
                DRY_RUN=true
                INSTALL_MODE="automatic"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
        esac
    done

    log_banner

    # Exibe modo de operação
    if $DRY_RUN; then
        echo -e "${ORANGE}╔══════════════════════════════════════════╗${NC}"
        echo -e "${ORANGE}║  ⚠ MODO SIMULAÇÃO (DRY-RUN)             ║${NC}"
        echo -e "${ORANGE}║  Nenhuma alteração será feita no sistema ║${NC}"
        echo -e "${ORANGE}╚══════════════════════════════════════════╝${NC}"
    else
        echo -e "Modo: $([ "$INSTALL_MODE" == "automatic" ] && echo -e "${ORANGE}Automático${NC}" || echo -e "${GREEN}Interativo${NC}")"
    fi

    # ------------------------------------------------------
    # Verificações do sistema
    # ------------------------------------------------------
    if ! $DRY_RUN; then
        if ! run_all_checks; then
            log_error "Verificações falharam. Corrija os problemas e tente novamente."
            exit 1
        fi
    else
        log_info "[DRY-RUN] Simulando verificações do sistema..."
        log_ok "[DRY-RUN] Verificações simuladas com sucesso"
    fi

    # ------------------------------------------------------
    # Atualização do sistema
    # ------------------------------------------------------
    if ask_install "Atualização do Sistema (recomendado)"; then
        log_separator "[1] Atualizando sistema"
        if $DRY_RUN; then
            log_info "[DRY-RUN] Executaria: apt update -y && apt upgrade -y"
            INSTALLED_SERVICES+=("Atualização (dry-run)")
        else
            apt update -y && apt upgrade -y
            log_ok "Sistema atualizado"
        fi
    else
        SKIPPED_SERVICES+=("Atualização")
    fi

    # ------------------------------------------------------
    # Pacotes essenciais
    # ------------------------------------------------------
    log_separator "[2] Pacotes essenciais"
    if $DRY_RUN; then
        log_info "[DRY-RUN] Instalaria pacotes essenciais"
        INSTALLED_SERVICES+=("Pacotes (dry-run)")
    else
        apt install -y bzip2 gzip coreutils screen curl wget unzip net-tools jq git \
            dos2unix nano make cmake build-essential fail2ban vnstat neofetch bc \
            htop iftop lsof rsyslog >/dev/null 2>&1
        log_ok "Pacotes instalados"
    fi

    # ------------------------------------------------------
    # Configurações de rede
    # ------------------------------------------------------
    if ! $DRY_RUN; then
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    fi

    TOTAL_STEPS=15
    CURRENT_STEP=2

    # ------------------------------------------------------
    # Instalação dos serviços
    # ------------------------------------------------------
    log_separator "INSTALAÇÃO DOS SERVIÇOS VPN"

    install_if_asked "Host/Domínio"        "Host"           "${SSH_REPO}/slhost.sh"              "slhost.sh"
    install_if_asked "SSH + OpenVPN"        "SSH-OVPN"       "${SSH_REPO}/ssh-vpn.sh"             "ssh-vpn.sh"
    install_if_asked "Xray Core"            "Xray"           "${XRAY_REPO}/ins-xray.sh"            "ins-xray.sh"
    install_if_asked "WebSocket SSH"        "WebSocket"      "${WEBSOCKET_REPO}/edu.sh"            "edu.sh"
    install_if_asked "SSTP VPN"             "SSTP"           "${SSTP_REPO}/sstp.sh"                "sstp.sh"
    install_if_asked "Shadowsocks"          "Shadowsocks"    "${SHADOWSOCKS_REPO}/sodosok.sh"      "sodosok.sh"
    install_if_asked "SSR"                  "SSR"            "${SSR_REPO}/ssr.sh"                  "ssr.sh"
    install_if_asked "WireGuard"            "WireGuard"      "${WIREGUARD_REPO}/wg.sh"             "wg.sh"
    install_if_asked "L2TP/IPSec"           "L2TP-IPSEC"     "${IPSEC_REPO}/ipsec.sh"              "ipsec.sh"
    install_if_asked "OHP Server"           "OHP"            "${OHP_REPO}/ohp.sh"                  "ohp.sh"
    install_if_asked "SlowDNS"              "SlowDNS"        "raw.githubusercontent.com/leitura/slowdns/main/install" "install-slowdns.sh"
    install_if_asked "XRAY GRPC"            "GRPC"           "${GRPC_REPO}/xray-grpc.sh"            "xray-grpc.sh"
    install_if_asked "Backup Automático"    "Backup"         "${BACKUP_REPO}/set-br.sh"             "set-br.sh"

    # ------------------------------------------------------
    # API Node.js (instalação especial)
    # ------------------------------------------------------
    if ask_install "API Node.js (gerenciamento remoto)"; then
        log_info "Instalando API..."
        if $DRY_RUN; then
            log_info "[DRY-RUN] Instalaria API Node.js"
            INSTALLED_SERVICES+=("API (dry-run)")
        else
            if download_file "https://${API_REPO}/install.sh" "/tmp/api-install.sh" "api-install.sh"; then
                TMP_FILES+=("/tmp/api-install.sh")
                chmod +x /tmp/api-install.sh
                if API_KEY="${API_KEY:-sakr}" bash /tmp/api-install.sh; then
                    INSTALLED_SERVICES+=("API")
                    log_ok "API instalada com sucesso!"
                else
                    FAILED_SERVICES+=("API")
                    log_fail "Falha na instalação da API"
                fi
                rm -f /tmp/api-install.sh
            else
                FAILED_SERVICES+=("API")
            fi
        fi
    else
        SKIPPED_SERVICES+=("API")
    fi

    # ------------------------------------------------------
    # Finalização
    # ------------------------------------------------------
    log_separator "FINALIZANDO"

    if ! $DRY_RUN; then
        echo "2.1" > /home/ver 2>/dev/null
        history -c 2>/dev/null

        log_info "Salvando scripts essenciais localmente..."
        mkdir -p /root/vpn-scripts 2>/dev/null

        save_local "https://${SSH_REPO}/menu.sh"       "/root/vpn-scripts" "menu.sh"
        save_local "https://${SSH_REPO}/addssh.sh"     "/root/vpn-scripts" "addssh.sh"
        save_local "https://${SSH_REPO}/delssh.sh"     "/root/vpn-scripts" "delssh.sh"
        save_local "https://${SSH_REPO}/renewssh.sh"   "/root/vpn-scripts" "renewssh.sh"

        log_info "Salvando API e scripts sakaru..."
        mkdir -p /usr/bin 2>/dev/null
        save_local "https://${API_REPO}/server.js"     "/opt/api-ssl"      "server.js"
        save_local "https://${SSH_REPO}/server.js"     "/root/ssh"         "server.js"

        # Scripts sakaru (wrappers nao-interativos para API)
        for script in sakaru sakaru2 sakaru3; do
            save_local "https://${API_REPO}/${script}"   "/usr/bin"  "${script}"
            chmod +x "/usr/bin/${script}" 2>/dev/null || true
        done
    else
        log_info "[DRY-RUN] Salvaria scripts em /root/vpn-scripts"
    fi

    # ------------------------------------------------------
    # Resumo
    # ------------------------------------------------------
    show_summary

    # Estatísticas
    echo ""
    local total=$(( ${#INSTALLED_SERVICES[@]} + ${#SKIPPED_SERVICES[@]} + ${#FAILED_SERVICES[@]} ))
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Estatísticas:${NC}"
    echo -e "  ${GREEN}✓ Instalados: ${#INSTALLED_SERVICES[@]}${NC}"
    echo -e "  ${ORANGE}→ Pulados:    ${#SKIPPED_SERVICES[@]}${NC}"
    echo -e "  ${RED}✘ Falhas:     ${#FAILED_SERVICES[@]}${NC}"
    echo -e "  ${CYAN}  Total:      ${total}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Reinicialização
    echo ""
    if $DRY_RUN; then
        log_info "[DRY-RUN] Simulação concluída. Nenhuma alteração foi feita."
    elif [ "$INSTALL_MODE" == "automatic" ]; then
        log_info "Instalação automática concluída."
        if [ ${#INSTALLED_SERVICES[@]} -gt 0 ]; then
            ask_install "Reiniciar servidor agora (recomendado)" "N" && {
                log_info "Reiniciando em 5 segundos..."
                sleep 5
                reboot
            } || log_info "Reinicie manualmente com: reboot"
        fi
    else
        if [ ${#INSTALLED_SERVICES[@]} -gt 0 ]; then
            ask_install "Reiniciar servidor agora (recomendado)" "N" && {
                log_info "Reiniciando em 5 segundos..."
                sleep 5
                reboot
            } || log_info "Reinicie manualmente com: reboot"
        fi
    fi
}

main "$@"
