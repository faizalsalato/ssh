#!/bin/bash
# ============================================================
# api/install.sh - Instalador da API Node.js VPN
# ============================================================
# Instala dependencias, server.js e configura PM2
# Uso: API_KEY="sua_chave" API_PORT=3000 bash api/install.sh
# ============================================================
set -euo pipefail

API_KEY="${API_KEY:-sakr}"
API_PORT="${API_PORT:-3000}"
API_DIR="${API_DIR:-/opt/api-ssl}"
GIT_BASE="${GIT_BASE:-raw.githubusercontent.com/faizalsalato/ssh/main}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

log_ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
log_err() { echo -e "${RED}[ERRO]${NC} $1"; }
log_info(){ echo -e "${CYAN}[*]${NC} $1"; }

log_info "Instalando API VPN na porta ${API_PORT}..."

# 1. Criar diretorio
mkdir -p "${API_DIR}"
cd "${API_DIR}"

# 2. Baixar server.js
log_info "Baixando server.js..."
curl -fsSL "https://${GIT_BASE}/api/server.js" -o "${API_DIR}/server.js" || {
    log_err "Falha ao baixar server.js"
    exit 1
}
chmod 644 "${API_DIR}/server.js"
log_ok "server.js baixado"

# 3. Criar package.json se nao existir
if [ ! -f "${API_DIR}/package.json" ]; then
    cat > "${API_DIR}/package.json" << 'JSONEOF'
{
  "name": "vpn-api",
  "version": "2.0.0",
  "description": "API REST para gerenciamento VPN/SSH",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-rate-limit": "^6.7.0"
  }
}
JSONEOF
    log_ok "package.json criado"
fi

# 4. Instalar dependencias Node.js
log_info "Instalando dependencias npm..."
if command -v npm &>/dev/null; then
    npm install --silent 2>&1 | tail -1 || log_err "npm install falhou"
else
    log_err "npm nao encontrado! Instale Node.js primeiro."
    exit 1
fi
log_ok "Dependencias instaladas"

# 5. Criar arquivo .env
cat > "${API_DIR}/.env" << ENVEOF
API_KEY=${API_KEY}
API_PORT=${API_PORT}
ENVEOF
chmod 600 "${API_DIR}/.env"
log_ok "Arquivo .env criado"

# 6. Configurar PM2
if command -v pm2 &>/dev/null; then
    log_info "Configurando PM2..."
    pm2 delete api-ssl 2>/dev/null || true
    pm2 start server.js --name api-ssl --env "${API_DIR}/.env" 2>&1 | tail -2
    pm2 save 2>/dev/null
    pm2 startup 2>/dev/null | grep 'sudo' | bash 2>/dev/null || true
    log_ok "PM2 configurado (api-ssl)"
else
    log_info "PM2 nao encontrado. Instalando..."
    npm install -g pm2 2>&1 | tail -1
    pm2 start server.js --name api-ssl
    pm2 save
    pm2 startup 2>/dev/null | grep 'sudo' | bash 2>/dev/null || true
    log_ok "PM2 instalado e configurado"
fi

# 7. Verificar
sleep 2
if curl -s "http://localhost:${API_PORT}/health" -H "x-api-key: ${API_KEY}" | grep -q '"status"'; then
    log_ok "API respondendo em http://localhost:${API_PORT}"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  API VPN instalada com sucesso!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "  URL:    http://SEU_IP:${API_PORT}"
    echo -e "  API Key: ${API_KEY}"
    echo -e "  Teste:  curl -H 'x-api-key: ${API_KEY}' http://localhost:${API_PORT}/health"
    echo -e "${GREEN}========================================${NC}"
else
    log_err "API nao respondeu. Verifique: pm2 logs api-ssl"
    exit 1
fi
