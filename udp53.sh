#!/bin/bash
# ============================================================
# udp53.sh - OpenVPN UDP 53 Ultra-Rápido (Any Linux)
# ============================================================
# Instala OpenVPN na porta 53 automaticamente.
# Compatível: Ubuntu 18/20/22/24, Debian 10/11/12, CentOS 7/8/9
# Uso: curl -sL bit.ly/??? | bash   OU   bash udp53.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
BOLD='\033[1m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

# ── Detectar IP ──
get_ip() {
    local ip
    ip=$(curl -4sS --max-time 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -4sS --max-time 5 ipv4.icanhazip.com 2>/dev/null) || \
    ip=$(curl -4sS --max-time 5 api.ipify.org 2>/dev/null) || \
    ip=$(hostname -I 2>/dev/null | awk '{print $1}') || \
    ip="SEU_IP"
    echo "$ip"
}

# ── Detectar OS ──
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$ID"
        VERSION_ID="${VERSION_ID:-0}"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        VERSION_ID=$(rpm -q --qf "%{VERSION}" centos-release 2>/dev/null || echo "7")
    else
        OS="unknown"
    fi
    # Normalizar
    case "$OS" in
        ubuntu|debian|centos|rhel|rocky|almalinux|fedora|amzn) ;;
        *) OS="debian" ;;
    esac
}

# ── Liberar porta 53 ──
free_port_53() {
    info "Verificando porta 53 UDP..."
    
    local has_conflict=false
    
    # 1. Parar systemd-resolved
    if systemctl is-active systemd-resolved &>/dev/null; then
        info "Parando systemd-resolved..."
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
        # Remover stub listener
        sed -i 's/^DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf 2>/dev/null || true
        if ! grep -q '^DNSStubListener' /etc/systemd/resolved.conf 2>/dev/null; then
            echo 'DNSStubListener=no' >> /etc/systemd/resolved.conf
        fi
        rm -f /etc/resolv.conf
        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
        has_conflict=true
    fi
    
    # 2. Parar dnsmasq
    if systemctl is-active dnsmasq &>/dev/null 2>&1; then
        info "Parando dnsmasq..."
        systemctl stop dnsmasq 2>/dev/null || true
        systemctl disable dnsmasq 2>/dev/null || true
        has_conflict=true
    fi
    
    # 3. Parar named/bind
    if systemctl is-active named &>/dev/null 2>&1; then
        info "Parando named/bind..."
        systemctl stop named 2>/dev/null || true
        systemctl disable named 2>/dev/null || true
        has_conflict=true
    fi
    
    # 4. Matar processos na porta 53
    local pids
    pids=$(ss -ulnp 'sport = :53' 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort -u)
    for pid in $pids; do
        warn "Matando processo PID=$pid na porta 53..."
        kill -9 "$pid" 2>/dev/null || true
        has_conflict=true
    done
    
    sleep 1
    
    # Verificar se liberou
    if ss -ulnp 'sport = :53' 2>/dev/null | grep -qv 'openvpn'; then
        if $has_conflict; then
            warn "Ainda há algo na porta 53. Forcando bind no IP externo..."
        fi
    else
        log "Porta 53 liberada com sucesso"
    fi
}

# ── Instalar OpenVPN ──
install_openvpn() {
    detect_os
    info "Sistema detectado: $OS $VERSION_ID"
    
    if command -v openvpn &>/dev/null; then
        log "OpenVPN já instalado: $(openvpn --version 2>/dev/null | head -1)"
        return 0
    fi
    
    log "Instalando OpenVPN..."
    case "$OS" in
        ubuntu|debian)
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq openvpn easy-rsa iptables 2>/dev/null
            ;;
        centos|rhel|rocky|almalinux|fedora|amzn)
            yum install -y epel-release 2>/dev/null || true
            yum install -y openvpn easy-rsa iptables 2>/dev/null
            ;;
        *)
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq openvpn easy-rsa iptables 2>/dev/null
            ;;
    esac
    
    if ! command -v openvpn &>/dev/null; then
        err "Falha ao instalar OpenVPN"
        exit 1
    fi
    log "OpenVPN instalado"
}

# ── Gerar certificados ──
generate_certs() {
    local dir="$1"
    mkdir -p "$dir"
    cd "$dir"
    
    log "Gerando certificados (3650 dias)..."
    
    # CA
    openssl req -new -x509 -days 3650 -nodes \
        -newkey rsa:2048 -keyout ca.key -out ca.crt \
        -subj '/CN=OVPN-UDP53-CA' 2>/dev/null
    
    # Server key + cert
    openssl req -new -nodes -newkey rsa:2048 \
        -keyout server.key -out server.csr \
        -subj '/CN=server' 2>/dev/null
    
    openssl x509 -req -days 3650 -in server.csr \
        -CA ca.crt -CAkey ca.key -CAcreateserial \
        -out server.crt 2>/dev/null
    
    # DH params
    openssl dhparam -out dh2048.pem 2048 2>/dev/null
    
    # Client cert (para .ovpn com cert inline, evita pergunta no Android)
    openssl req -new -nodes -newkey rsa:2048 \
        -keyout client.key -out client.csr \
        -subj '/CN=client' 2>/dev/null
    openssl x509 -req -days 3650 -in client.csr \
        -CA ca.crt -CAkey ca.key -CAcreateserial \
        -extfile <(printf "keyUsage=digitalSignature\\nextendedKeyUsage=clientAuth") \
        -out client.crt 2>/dev/null
    
    rm -f server.csr client.csr
    log "Certificados gerados com sucesso"
}

# ── Configurar firewall ──
setup_firewall() {
    local ip="$1"
    local port="$2"
    local tun_net="$3"
    
    # Habilitar IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf 2>/dev/null || true
    if ! grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null; then
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    fi
    
    # Interface externa
    local iface
    iface=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
    [ -z "$iface" ] && iface=$(ip link | grep -oP '^\d+: \K[^:@]+' | grep -v lo | head -1)
    [ -z "$iface" ] && iface="eth0"
    
    log "Interface: $iface | IP: $ip"
    
    # NAT (MASQUERADE)
    iptables -t nat -C POSTROUTING -s "${tun_net}/24" -o "$iface" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "${tun_net}/24" -o "$iface" -j MASQUERADE
    
    # Permitir OpenVPN
    iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p udp --dport "$port" -j ACCEPT
    
    # Forward TUN
    iptables -C FORWARD -i tun+ -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i tun+ -j ACCEPT
    
    iptables -C FORWARD -o tun+ -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -o tun+ -j ACCEPT
    
    # Salvar regras
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save 2>/dev/null || true
    elif command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
    log "Firewall configurado"
}

# ── Criar config do servidor ──
create_server_config() {
    local dir="$1"
    local port="$2"
    local ip="$3"
    
    cat > "$dir/server-udp53.conf" << EOF
local ${ip}
port ${port}
proto udp
dev tun
ca ${dir}/ca.crt
cert ${dir}/server.crt
key ${dir}/server.key
dh ${dir}/dh2048.pem
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
verify-client-cert none
username-as-common-name
auth SHA256
cipher AES-128-GCM
data-ciphers AES-128-GCM:AES-256-GCM:CHACHA20-POLY1305
server 10.9.0.0 255.255.255.0
push "dhcp-option DNS 1.0.0.1"
push "dhcp-option DNS 1.1.1.1"
tun-mtu 1500
mssfix 1350
push "sndbuf 1048576"
push "rcvbuf 1048576"
push "redirect-gateway def1"
keepalive 10 60
topology subnet
fast-io
sndbuf 1048576
rcvbuf 1048576
persist-key
persist-tun
tls-server
tls-version-min 1.2
status ${dir}/openvpn-udp53.log
verb 1
explicit-exit-notify 1
EOF
    log "Config do servidor criada"
}

# ── Criar .ovpn do cliente ──
create_client_ovpn() {
    local dir="$1"
    local ip="$2"
    local out="$3"
    
    local ca cert key
    ca=$(cat "$dir/ca.crt")
    cert=$(cat "$dir/client.crt")
    key=$(cat "$dir/client.key")
    
    cat > "$out" << EOF
client
dev tun
proto udp
remote ${ip} 53
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
float
reneg-sec 0
fast-io
sndbuf 1048576
rcvbuf 1048576
verb 1
<ca>
${ca}
</ca>
<cert>
${cert}
</cert>
<key>
${key}
</key>
EOF
    log "Cliente .ovpn criado: $out"
}

# ── Service systemd ──
create_service() {
    local dir="$1"
    
    cat > /etc/systemd/system/openvpn-udp53.service << EOF
[Unit]
Description=OpenVPN UDP 53 Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/openvpn --config ${dir}/server-udp53.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    log "Serviço systemd criado"
}

# ===============================================================
# MAIN
# ===============================================================
main() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   OpenVPN UDP 53 - Ultra Rápido v1.0    ║"
    echo "║   Instalador Automático Any Linux       ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Verificar root
    if [ "$EUID" -ne 0 ]; then
        err "Execute como root: sudo bash $0"
        exit 1
    fi
    
    local OVPN_DIR="/etc/openvpn-udp53"
    local OVPN_PORT="53"
    local OVPN_IP
    OVPN_IP=$(get_ip)
    
    log "IP do servidor: $OVPN_IP"
    
    # 1. Liberar porta 53
    free_port_53
    
    # 2. Instalar dependências
    install_openvpn
    
    # 3. Gerar certificados
    generate_certs "$OVPN_DIR"
    
    # 4. Config do servidor
    create_server_config "$OVPN_DIR" "$OVPN_PORT" "$OVPN_IP"
    
    # 5. Config cliente .ovpn
    create_client_ovpn "$OVPN_DIR" "$OVPN_IP" "/root/udp53.ovpn"
    
    # 6. Firewall + NAT
    setup_firewall "$OVPN_IP" "$OVPN_PORT" "10.9.0.0"
    
    # 7. Serviço systemd
    create_service "$OVPN_DIR"
    
    # 8. Iniciar
    log "Iniciando OpenVPN UDP 53..."
    systemctl enable openvpn-udp53 2>/dev/null || true
    systemctl restart openvpn-udp53 2>/dev/null || {
        warn "systemctl falhou, iniciando manualmente..."
        /usr/sbin/openvpn --config "${OVPN_DIR}/server-udp53.conf" --daemon 2>/dev/null &
        sleep 2
    }
    
    # 9. Verificar
    sleep 2
    if ss -ulnp 'sport = :53' 2>/dev/null | grep -q openvpn; then
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ OpenVPN UDP 53 ATIVO!              ║${NC}"
        echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                         ║${NC}"
        echo -e "${GREEN}║   Servidor: ${OVPN_IP}:53${NC}"
        echo -e "${GREEN}║   Config:   /root/udp53.ovpn${NC}"
        echo -e "${GREEN}║   Criar:    useradd -M -s /bin/false X${NC}"
        echo -e "${GREEN}║   Senha:    passwd X${NC}"
        echo -e "${GREEN}║   Log:      ${OVPN_DIR}/openvpn-udp53.log${NC}"
        echo -e "${GREEN}║   Status:   systemctl status openvpn-udp53${NC}"
        echo -e "${GREEN}║                                         ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
        echo ""
    else
        echo ""
        warn "OpenVPN pode não ter iniciado. Verifique:"
        echo "  journalctl -u openvpn-udp53 --no-pager -n 20"
        echo "  cat ${OVPN_DIR}/openvpn-udp53.log"
    fi
}

main "$@"
