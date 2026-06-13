#!/bin/bash
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

clear
echo -e "${green}╔════════════════════════════════════════════════╗${NC}"
echo -e "${green}║   CONFIGURAÇÃO MANUAL DE DOMÍNIO (SUBDOMAIN)   ║${NC}"
echo -e "${green}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Arquivo para guardar a configuração
mkdir -p /root/.config
CONFIG_FILE="/root/.config/vpn_manual_config.conf"

# Função para salvar a configuração
save_config() {
    cat > "$CONFIG_FILE" <<EOF
SUB_DOMAIN=$SUB_DOMAIN
NS_DOMAIN=$NS_DOMAIN
LAST_UPDATE="$(date)"
EOF
    chmod 600 "$CONFIG_FILE"
}

# Verifica se já existe uma configuração salva
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo -e "${green}Configuração salva encontrada!${NC}"
    echo "  Subdomínio: $SUB_DOMAIN"
    echo "  NS Domínio: $NS_DOMAIN"
    echo ""
    read -p "Deseja usar esta configuração? (s/n): " use_existing
    
    if [[ "$use_existing" != "s" && "$use_existing" != "S" ]]; then
        echo ""
        read -p "Digite o Subdomínio (ex: sub.dominio.com): " SUB_DOMAIN
        read -p "Digite o NS Domínio (ex: ns-sub.dominio.com): " NS_DOMAIN
        save_config
    fi
else
    read -p "Digite o Subdomínio (ex: sub.dominio.com): " SUB_DOMAIN
    read -p "Digite o NS Domínio (ex: ns-sub.dominio.com): " NS_DOMAIN
    save_config
fi

# Valida se os campos não estão vazios
if [ -z "$SUB_DOMAIN" ] || [ -z "$NS_DOMAIN" ]; then
    echo -e "${red}Erro: Os domínios não podem ficar vazios! Instalação interrompida.${NC}"
    exit 1
fi

# Cria as pastas necessárias
mkdir -p /var/lib/crot

# Limpa resíduos antigos
rm -f /root/nsdomain
rm -f /root/subdomain
rm -f /var/lib/crot/subdomain.conf

# Salva as configurações nos arquivos específicos
echo "IP=${SUB_DOMAIN}" > /var/lib/crot/subdomain.conf
echo "$SUB_DOMAIN" > /root/subdomain
echo "$NS_DOMAIN" > /root/nsdomain

echo ""
echo -e "${green}Configuração manual salva com sucesso!${NC}"
echo "Host : $SUB_DOMAIN"
echo "Host NS : $NS_DOMAIN"
echo "=========================================="