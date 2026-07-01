#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "======================================="
echo "     INSTALADOR API SSH PANEL"
echo "======================================="
echo -e "${NC}"

if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Execute como root.${NC}"
    exit 1
fi

echo "Atualizando sistema..."
apt update -y

echo "Instalando dependências..."
apt install -y curl wget git

##########################################
# NODEJS
##########################################

if ! command -v node >/dev/null 2>&1; then
    echo "Instalando NodeJS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
fi

##########################################
# PM2
##########################################

if ! command -v pm2 >/dev/null 2>&1; then
    echo "Instalando PM2..."
    npm install -g pm2
fi

##########################################
# API
##########################################

mkdir -p /opt/api-ssl
cd /opt/api-ssl

echo "Baixando arquivos..."

wget -q -O server.js https://raw.githubusercontent.com/faizalsalato/ssh/main/api/server.js
wget -q -O package.json https://raw.githubusercontent.com/faizalsalato/ssh/main/api/package.json

echo "Instalando módulos..."

npm install --omit=dev

##########################################
# PM2
##########################################

echo "Parando instância antiga (se existir)..."

pm2 delete api-ssl >/dev/null 2>&1

echo "Iniciando API..."

pm2 start server.js \
    --name api-ssl \
    --interpreter node

pm2 save

pm2 startup systemd -u root --hp /root >/tmp/pm2_startup

bash -c "$(tail -1 /tmp/pm2_startup)"

##########################################

echo
echo -e "${GREEN}======================================="
echo "API instalada com sucesso!"
echo "======================================="
echo
echo "Status do PM2:"
pm2 status
echo
echo "Logs:"
echo "pm2 logs api-ssl"
echo
echo "Porta utilizada:"
ss -lntp | grep 3000
echo "======================================="
echo -e "${NC}"
