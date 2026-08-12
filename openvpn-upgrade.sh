#!/bin/bash
# ============================================================
# openvpn-upgrade.sh - Instala última versão do OpenVPN
# ============================================================
# Compila do source com otimizações de velocidade
# Uso: bash openvpn-upgrade.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $1"; }
info(){ echo -e "${CYAN}[*]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then echo "Execute como root"; exit 1; fi

# Dependencias
info "Instalando dependencias..."
apt-get update -qq 2>/dev/null
apt-get install -y -qq build-essential libssl-dev liblzo2-dev libpam0g-dev liblz4-dev libnl-genl-3-dev pkg-config libcap-ng-dev curl 2>/dev/null

# Buscar última versão
LATEST=$(curl -sL https://api.github.com/repos/OpenVPN/openvpn/releases/latest 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null || echo "v2.7.6")
VERSION="${LATEST#v}"
info "Última versão: ${LATEST}"

# Download
cd /tmp
curl -sL "https://swupdate.openvpn.org/community/releases/openvpn-${VERSION}.tar.gz" -o openvpn.tar.gz
tar xzf openvpn.tar.gz
cd openvpn-${VERSION}

# Compilar com otimizações
info "Compilando com -O3 -march=native -flto..."
CFLAGS="-O3 -march=native -mtune=native -flto" ./configure --prefix=/usr/local --enable-plugin-auth-pam 2>/dev/null
make -j$(nproc) 2>/dev/null

# Parar serviços
systemctl stop openvpn-server@* 2>/dev/null || true
sleep 1

# Instalar
make install 2>/dev/null
cp -f src/openvpn/openvpn /usr/sbin/openvpn
cp -f src/plugins/auth-pam/.libs/openvpn-plugin-auth-pam.so /usr/lib/openvpn/ 2>/dev/null || true

log "OpenVPN ${LATEST} instalado!"
/usr/sbin/openvpn --version | head -1

# Reiniciar
systemctl start openvpn-server@* 2>/dev/null || true
log "Serviços reiniciados"
