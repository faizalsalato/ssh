#!/bin/bash
#===============================================================================
# OpenVPN Ultra-Rápido — Instalador Automático (UDP 53 + DCO)
# Para VPS nova Ubuntu 22.04/24.04 ou Debian 11/12
#
# Uso:  bash install-openvpn-udp53.sh [nome-do-cliente]
#       Ex.: bash install-openvpn-udp53.sh cliente1
#
# O que faz:
#   1. Libera a porta 53/UDP (desativa stub do systemd-resolved e mata
#      qualquer processo escutando na porta)
#   2. Instala OpenVPN + Easy-RSA + módulo DCO (aceleração em kernel)
#   3. Gera PKI completa (CA, servidor, cliente) e chave tls-crypt
#   4. Configura servidor otimizado: AES-256-GCM, ECDH, buffers 1MB,
#      túnel completo (redirect-gateway), NAT persistente
#   5. Gera /root/<cliente>.ovpn pronto para importar
#===============================================================================
set -euo pipefail

CLIENT_NAME="${1:-cliente1}"
VPN_NET="10.66.66.0"
VPN_MASK="255.255.255.0"
VPN_CIDR="10.66.66.0/24"

#------------------------------------------------------------------------------
# Funções auxiliares
#------------------------------------------------------------------------------
log()  { echo -e "\e[32m[OK]\e[0m $*"; }
info() { echo -e "\e[36m[..]\e[0m $*"; }
die()  { echo -e "\e[31m[ERRO]\e[0m $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Execute como root."

#------------------------------------------------------------------------------
# 0. Detectar IP público e interface de saída
#------------------------------------------------------------------------------
info "Detectando rede..."
SERVER_IP="$(curl -4 -s --max-time 5 ifconfig.me || true)"
[ -z "$SERVER_IP" ] && SERVER_IP="$(hostname -I | awk '{print $1}')"
WAN_IF="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
[ -n "$SERVER_IP" ] && [ -n "$WAN_IF" ] || die "Não foi possível detectar IP/interface."
log "IP público: $SERVER_IP | Interface: $WAN_IF"

#------------------------------------------------------------------------------
# 1. Parar/liberar TODA a porta 53
#------------------------------------------------------------------------------
info "Liberando porta 53/UDP..."

# Desativar o stub listener do systemd-resolved (127.0.0.53:53)
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
    mkdir -p /etc/systemd/resolved.conf.d
    printf '[Resolve]\nDNSStubListener=no\n' > /etc/systemd/resolved.conf.d/99-no-stub.conf
    systemctl restart systemd-resolved
fi

# Parar e desabilitar QUALQUER instância openvpn-server@ anterior
# (o systemd reinicia serviços mortos — sem isso ela reconquista a porta 53)
for u in $(systemctl list-units --all 'openvpn-server@*' --no-legend 2>/dev/null | awk '{print $1}'); do
    systemctl stop "$u" 2>/dev/null || true
    systemctl disable "$u" >/dev/null 2>&1 || true
done

# Matar qualquer outro processo escutando na porta 53 (udp/tcp)
if command -v fuser >/dev/null 2>&1; then
    fuser -k 53/udp 2>/dev/null || true
    fuser -k 53/tcp 2>/dev/null || true
fi

# Se a porta ainda estiver presa por um socket órfão do kernel (vazamento
# do DCO quando uma instância é morta com SIGKILL), recarregar o módulo resolve.
sleep 1
if ss -uln | grep -q ':53 '; then
    info "Porta 53 presa por socket órfão — recarregando módulo DCO..."
    rmmod ovpn_dco_v2 2>/dev/null || rmmod dco 2>/dev/null || true
    sleep 1
    modprobe ovpn_dco_v2 2>/dev/null || modprobe dco 2>/dev/null || true
    sleep 1
fi
ss -uln | grep -q ':53 ' && die "Porta 53 continua ocupada mesmo após limpeza." || log "Porta 53 livre."

# Garantir resolução DNS funcional após liberar a porta
if ! grep -q nameserver /etc/resolv.conf 2>/dev/null; then
    rm -f /etc/resolv.conf
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
fi
log "Porta 53 livre."

#------------------------------------------------------------------------------
# 2. Instalar pacotes
#------------------------------------------------------------------------------
info "Instalando pacotes (openvpn, easy-rsa, dco, iptables-persistent)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -qq
apt-get install -y -qq openvpn easy-rsa openvpn-dco-dkms iptables-persistent curl >/dev/null
log "Pacotes instalados ($(openvpn --version | head -1 | awk '{print $1,$2}'))."

#------------------------------------------------------------------------------
# 3. Carregar módulo DCO (aceleração em kernel)
#------------------------------------------------------------------------------
info "Carregando módulo DCO..."
modprobe ovpn-dco-v2 2>/dev/null || modprobe dco 2>/dev/null || \
    info "AVISO: módulo DCO não disponível neste kernel — seguindo sem offload."
echo "ovpn-dco-v2" > /etc/modules-load.d/openvpn-dco.conf 2>/dev/null || true
lsmod | grep -q dco && log "DCO ativo no kernel." || log "DCO indisponível (OpenVPN funcionará em modo userspace)."

#------------------------------------------------------------------------------
# 4. Gerar PKI (pula se já existir — reinstalação segura)
#------------------------------------------------------------------------------
if [ ! -f /etc/openvpn/easy-rsa/pki/ca.crt ]; then
    info "Gerando PKI (CA, servidor, cliente '$CLIENT_NAME')..."
    cp -r /usr/share/easy-rsa /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa
    ./easyrsa --batch init-pki >/dev/null
    EASYRSA_REQ_CN="vpn-ca" EASYRSA_BATCH=1 ./easyrsa build-ca nopass >/dev/null
    EASYRSA_BATCH=1 ./easyrsa build-server-full vpn-server nopass >/dev/null
    EASYRSA_BATCH=1 ./easyrsa build-client-full "$CLIENT_NAME" nopass >/dev/null
    EASYRSA_BATCH=1 ./easyrsa gen-crl >/dev/null
    log "PKI gerada."
else
    log "PKI existente encontrada — reaproveitando."
    cd /etc/openvpn/easy-rsa
    # garante que o certificado do servidor existe
    if [ ! -f /etc/openvpn/easy-rsa/pki/issued/vpn-server.crt ]; then
        EASYRSA_BATCH=1 ./easyrsa build-server-full vpn-server nopass >/dev/null
        log "Certificado do servidor 'vpn-server' criado."
    fi
    # garante que o certificado do cliente pedido existe
    if [ ! -f "/etc/openvpn/easy-rsa/pki/issued/${CLIENT_NAME}.crt" ]; then
        EASYRSA_BATCH=1 ./easyrsa build-client-full "$CLIENT_NAME" nopass >/dev/null
        log "Certificado do cliente '$CLIENT_NAME' criado."
    fi
fi

#------------------------------------------------------------------------------
# 5. Chave tls-crypt
#------------------------------------------------------------------------------
[ -f /etc/openvpn/server/tls-crypt.key ] || openvpn --genkey secret /etc/openvpn/server/tls-crypt.key

#------------------------------------------------------------------------------
# 6. Configuração do servidor (otimizada para velocidade)
#------------------------------------------------------------------------------
info "Escrevendo configuração do servidor..."
mkdir -p /var/log/openvpn
cat > /etc/openvpn/server/vpn.conf <<EOF
port 53
proto udp
dev tun
topology subnet
server ${VPN_NET} ${VPN_MASK}
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/vpn-server.crt
key /etc/openvpn/easy-rsa/pki/private/vpn-server.key
dh none
ecdh-curve prime256v1
tls-crypt /etc/openvpn/server/tls-crypt.key
crl-verify /etc/openvpn/easy-rsa/pki/crl.pem
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
auth SHA256
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
push "redirect-gateway def1 bypass-dhcp"
keepalive 10 60
persist-key
persist-tun
explicit-exit-notify 1
sndbuf 1048576
rcvbuf 1048576
fast-io
status /var/log/openvpn/status.log
log-append /var/log/openvpn/server.log
verb 3
EOF
log "Configuração escrita (/etc/openvpn/server/vpn.conf)."

#------------------------------------------------------------------------------
# 7. IP forwarding + NAT persistente
#------------------------------------------------------------------------------
info "Configurando IP forwarding e NAT..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf >/dev/null

iptables -t nat -C POSTROUTING -s "$VPN_CIDR" -o "$WAN_IF" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$VPN_CIDR" -o "$WAN_IF" -j MASQUERADE
iptables -C FORWARD -s "$VPN_CIDR" -j ACCEPT 2>/dev/null || iptables -A FORWARD -s "$VPN_CIDR" -j ACCEPT
iptables -C FORWARD -d "$VPN_CIDR" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -d "$VPN_CIDR" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
netfilter-persistent save >/dev/null 2>&1 || iptables-save > /etc/iptables/rules.v4
log "NAT configurado e persistido."

#------------------------------------------------------------------------------
# 8. Iniciar serviço
#------------------------------------------------------------------------------
info "Iniciando serviço OpenVPN..."
# Garantia extra: nenhuma outra instância pode estar de posse da porta 53
for u in $(systemctl list-units --all 'openvpn-server@*' --no-legend 2>/dev/null | awk '{print $1}'); do
    [ "$u" = "openvpn-server@vpn.service" ] && continue
    systemctl stop "$u" 2>/dev/null || true
done
sleep 1
systemctl enable openvpn-server@vpn >/dev/null 2>&1
systemctl restart openvpn-server@vpn
sleep 2
systemctl is-active --quiet openvpn-server@vpn || {
    journalctl -u openvpn-server@vpn --no-pager -n 15
    die "Serviço falhou ao iniciar — veja logs acima."
}
ss -ulnp | grep -q ':53 ' && log "Servidor ativo e escutando na UDP 53." || die "Porta 53 não está escutando!"

#------------------------------------------------------------------------------
# 9. Gerar arquivo do cliente (.ovpn inline)
#------------------------------------------------------------------------------
info "Gerando /root/${CLIENT_NAME}.ovpn..."
O="/root/${CLIENT_NAME}.ovpn"
cat > "$O" <<EOF
client
dev tun
proto udp
remote ${SERVER_IP} 53
resolv-retry infinite
nobind
persist-key
persist-tun
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
auth SHA256
sndbuf 1048576
rcvbuf 1048576
fast-io
verb 3
EOF
{
    echo '<ca>'
    cat /etc/openvpn/easy-rsa/pki/ca.crt
    echo '</ca>'
    echo '<cert>'
    openssl x509 -in "/etc/openvpn/easy-rsa/pki/issued/${CLIENT_NAME}.crt"
    echo '</cert>'
    echo '<key>'
    cat "/etc/openvpn/easy-rsa/pki/private/${CLIENT_NAME}.key"
    echo '</key>'
    echo '<tls-crypt>'
    cat /etc/openvpn/server/tls-crypt.key
    echo '</tls-crypt>'
} >> "$O"
chmod 600 "$O"

#------------------------------------------------------------------------------
# Resumo
#------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  INSTALAÇÃO CONCLUÍDA"
echo "============================================================"
echo "  Servidor : ${SERVER_IP}:53/udp (túnel completo)"
echo "  Rede VPN : ${VPN_CIDR}"
echo "  Cliente  : /root/${CLIENT_NAME}.ovpn"
echo ""
echo "  Baixe o arquivo .ovpn e importe no OpenVPN Connect:"
echo "    scp root@${SERVER_IP}:/root/${CLIENT_NAME}.ovpn ."
echo ""
echo "  Novos clientes:"
echo "    cd /etc/openvpn/easy-rsa"
echo "    EASYRSA_BATCH=1 ./easyrsa build-client-full NOME nopass"
echo "============================================================"
