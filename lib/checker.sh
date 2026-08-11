#!/bin/bash
# ============================================================
# lib/checker.sh - Validação do sistema e pré-requisitos
# ============================================================
# Uso: source lib/checker.sh
# ============================================================

# ----------------------------------------------------------
# Constantes
# ----------------------------------------------------------
readonly MIN_RAM_MB=512
readonly MIN_DISK_GB=5
readonly REQUIRED_CMDS="wget curl netstat ip systemctl"

# Sistema operacional detectado
OS_NAME=""
OS_VERSION=""
OS_ID=""

# ----------------------------------------------------------
# Verificações
# ----------------------------------------------------------

check_root() {
    if [ "${EUID}" -ne 0 ]; then
        log_fail "Este script precisa ser executado como root!"
        echo "  Use: sudo bash install.sh"
        return 1
    fi
    log_ok "Executando como root"
    return 0
}

check_openvz() {
    if [ "$(systemd-detect-virt 2>/dev/null)" == "openvz" ]; then
        log_fail "OpenVZ não é suportado! Use KVM ou Xen."
        return 1
    fi
    log_ok "Virtualização: $(systemd-detect-virt 2>/dev/null || echo 'desconhecida')"
    return 0
}

check_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
    else
        log_fail "Não foi possível detectar o sistema operacional"
        return 1
    fi

    case "$OS_ID" in
        debian)
            if [ "$(echo "$OS_VERSION" | cut -d. -f1)" -lt 9 ]; then
                log_fail "Debian $OS_VERSION não suportado. Mínimo: Debian 9"
                return 1
            fi
            ;;
        ubuntu)
            if [ "$(echo "$OS_VERSION" | cut -d. -f1)" -lt 18 ]; then
                log_fail "Ubuntu $OS_VERSION não suportado. Mínimo: Ubuntu 18.04"
                return 1
            fi
            ;;
        *)
            log_warn "SO '$OS_NAME' não foi testado. Pode funcionar, mas sem garantias."
            ;;
    esac

    log_ok "Sistema: $OS_NAME $OS_VERSION"
    return 0
}

check_ram() {
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))

    if [ "$total_ram_mb" -lt "$MIN_RAM_MB" ]; then
        log_warn "RAM: ${total_ram_mb}MB (mínimo recomendado: ${MIN_RAM_MB}MB)"
        echo "  Alguns serviços podem não funcionar corretamente."
        return 0  # Warning, não erro
    fi
    log_ok "RAM: ${total_ram_mb}MB"
    return 0
}

check_disk() {
    local disk_avail=$(df / --output=avail -BG 2>/dev/null | tail -1 | tr -d ' G')
    if [ -z "$disk_avail" ]; then
        disk_avail=$(df / -BG 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
    fi

    if [ -n "$disk_avail" ] && [ "$disk_avail" -lt "$MIN_DISK_GB" ]; then
        log_warn "Disco livre: ${disk_avail}GB (mínimo: ${MIN_DISK_GB}GB)"
        return 0
    fi
    log_ok "Disco livre: ${disk_avail:-?}GB"
    return 0
}

check_network() {
    log_info "Verificando conectividade..."

    # Testa DNS
    if ! nslookup google.com >/dev/null 2>&1 && ! host google.com >/dev/null 2>&1; then
        log_warn "DNS pode estar com problema. Corrigindo..."
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi

    # Testa conectividade
    if ! ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
        if ! ping -c 2 -W 3 1.1.1.1 >/dev/null 2>&1; then
            log_error "Sem conectividade com a internet!"
            return 1
        fi
    fi

    # Detecta IP
    local myip=""
    for try in 1 2 3; do
        myip=$(curl -sS --connect-timeout 5 ifconfig.me 2>/dev/null) && break
        myip=$(curl -sS --connect-timeout 5 ipinfo.io/ip 2>/dev/null) && break
        myip=$(curl -sS --connect-timeout 5 ipv4.icanhazip.com 2>/dev/null) && break
        sleep 1
    done

    if [ -z "$myip" ]; then
        log_error "Não foi possível detectar o IP público!"
        return 1
    fi

    export SERVER_IP="$myip"
    log_ok "Conectividade OK - IP: $SERVER_IP"
    return 0
}

check_commands() {
    local missing=""

    for cmd in $REQUIRED_CMDS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log_warn "Comandos faltando:$missing"
        log_info "Instalando dependências básicas..."
        apt update -qq && apt install -y -qq wget curl net-tools >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_error "Falha ao instalar dependências básicas"
            return 1
        fi
    fi

    log_ok "Todos os comandos necessários estão disponíveis"
    return 0
}

# ----------------------------------------------------------
# Verificação completa (roda todas)
# ----------------------------------------------------------

run_all_checks() {
    log_separator "VERIFICAÇÕES DO SISTEMA"

    local all_ok=true

    check_root      || all_ok=false
    check_openvz    || all_ok=false
    check_os        || all_ok=false
    check_ram
    check_disk
    check_network   || all_ok=false
    check_commands  || all_ok=false

    if ! $all_ok; then
        log_separator "FALHA NAS VERIFICAÇÕES"
        log_error "Corrija os problemas acima e execute novamente."
        return 1
    fi

    log_separator "VERIFICAÇÕES CONCLUÍDAS" "✓"
    log_ok "Sistema pronto para instalação!"
    return 0
}