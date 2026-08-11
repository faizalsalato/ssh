#!/bin/bash
# ============================================================
# lib/logger.sh - Sistema de logging avançado
# ============================================================
# Uso: source lib/logger.sh
# ============================================================

# Níveis de log
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Configuração padrão
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"
LOG_FILE="${LOG_FILE:-/root/install-vpn.log}"
LOG_DIR="$(dirname "$LOG_FILE")"

# Cria diretório de log se não existir
mkdir -p "$LOG_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null

# Inicializa o arquivo de log
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo " LOG INICIADO: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# ----------------------------------------------------------
# Funções de log
# ----------------------------------------------------------

log_debug() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]; then
        local msg="[DEBUG] $(date '+%H:%M:%S') $*"
        echo -e "${PURPLE}${msg}${NC}" >&2
        echo "$msg" >> "$LOG_FILE"
    fi
}

log_info() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]; then
        local msg="[INFO]  $(date '+%H:%M:%S') $*"
        echo -e "${GREEN}${msg}${NC}"
        echo "$msg" >> "$LOG_FILE"
    fi
}

log_warn() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_WARN" ]; then
        local msg="[WARN]  $(date '+%H:%M:%S') $*"
        echo -e "${ORANGE}${msg}${NC}" >&2
        echo "$msg" >> "$LOG_FILE"
    fi
}

log_error() {
    if [ "$LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ]; then
        local msg="[ERROR] $(date '+%H:%M:%S') $*"
        echo -e "${RED}${msg}${NC}" >&2
        echo "$msg" >> "$LOG_FILE"
    fi
}

# Log de sucesso (sempre visível)
log_ok() {
    local msg="[OK]    $(date '+%H:%M:%S') $*"
    echo -e "${GREEN_BOLD}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# Log de falha (sempre visível)
log_fail() {
    local msg="[FALHA] $(date '+%H:%M:%S') $*"
    echo -e "${RED_BOLD}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
}

# Separador visual
log_separator() {
    local title="${1:-}"
    local char="${2:-=}"
    local width=60
    echo ""
    echo -e "${CYAN}$(printf '%*s' "$width" | tr ' ' "$char")${NC}"
    if [ -n "$title" ]; then
        echo -e "${CYAN_BOLD}  $title${NC}"
        echo -e "${CYAN}$(printf '%*s' "$width" | tr ' ' "$char")${NC}"
    fi
    echo ""
}

# Banner do instalador
log_banner() {
    clear
    echo -e "${CYAN_BOLD}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║        AUTO SCRIPT VPN - INSTALADOR GUIADO           ║"
    echo "║              Mod By blaylook                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  Log: ${YELLOW_BOLD}${LOG_FILE}${NC}"
    echo ""
}