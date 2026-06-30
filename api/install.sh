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
# API
##########################################

mkdir -p /opt/api-ssl
cd /opt/api-ssl

echo "Baixando arquivos..."

wget -q -O server.js https://raw.githubusercontent.com/faizalsalato/ssh/main/api/server.js
wget -q -O package.json https://raw.githubusercontent.com/faizalsalato/ssh/main/api/package.json

echo "Instalando módulos..."

npm install

##########################################
# SYSTEMD
##########################################

cat >/etc/systemd/system/api-ssl.service <<EOF
[Unit]
Description=API SSH PANEL
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/api-ssl
ExecStart=/usr/bin/node /opt/api-ssl/server.js
Restart=always
RestartSec=5
User=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable api-ssl
systemctl restart api-ssl

##########################################

echo
echo -e "${GREEN}======================================="
echo "API instalada com sucesso!"
echo "======================================="
echo
echo "Status:"
systemctl --no-pager status api-ssl | head -12
echo
echo "Porta utilizada:"
ss -lntp | grep 3300
echo "======================================="
echo -e "${NC}"
