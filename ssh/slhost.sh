#!/bin/bash
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

clear
echo -e "${green}╔════════════════════════════════════════════════╗${NC}"
echo -e "${green}║     CONFIGURAÇÃO MANUAL DE DOMÍNIO (ROTATEEL)  ║${NC}"
echo -e "${green}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Antes de continuar, certifique-se de que já criou no Cloudflare:"
echo "1. Registro A  (ex: vpn.seu-dominio.com) -> IP da sua VPS (Nuvem Cinza/Desativada)"
echo "2. Registro NS (ex: ns.seu-dominio.com)  -> vpn.seu-dominio.com"
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
    echo "  Subdomínio Principal: $SUB_DOMAIN"
    echo "  Subdomínio SlowDNS: $NS_DOMAIN"
    echo ""
    read -p "Deseja usar esta configuração? (s/n): " use_existing
    
    # Se o usuário não quiser usar a antiga, pede uma nova
    if [[ "$use_existing" != "s" && "$use_existing" != "S" ]]; then
        echo ""
        read -p "Digite o seu Subdomínio Principal (ex: vpn.sakaru.pro): " SUB_DOMAIN
        read -p "Digite o seu Subdomínio SlowDNS (ex: ns.sakaru.pro): " NS_DOMAIN
        save_config
    fi
else
    # Primeira vez rodando o script
    read -p "Digite o seu Subdomínio Principal (ex: vpn.sakaru.pro): " SUB_DOMAIN
    read -p "Digite o seu Subdomínio SlowDNS (ex: ns.sakaru.pro): " NS_DOMAIN
    save_config
fi

# Valida se os campos não estão vazios
if [ -z "$SUB_DOMAIN" ] || [ -z "$NS_DOMAIN" ]; then
    echo -e "${red}Erro: Os domínios não podem ficar vazios! Instalação interrompida.${NC}"
    exit 1
fi

# Cria as pastas necessárias e limpa resíduos
mkdir -p /etc/xray
mkdir -p /etc/v2ray
mkdir -p /var/lib/crot

rm -f /root/domain /etc/v2ray/domain /etc/xray/domain /root/nsdomain /var/lib/crot/ipvps.conf

# Salva as configurações nos arquivos que os próximos scripts vão ler
echo "$SUB_DOMAIN" > /root/domain
echo "$SUB_DOMAIN" > /etc/xray/domain
echo "$SUB_DOMAIN" > /etc/v2ray/domain
echo "$NS_DOMAIN" > /root/nsdomain
echo "IP=${SUB_DOMAIN}" > /var/lib/crot/ipvps.conf

echo ""
echo -e "${green}Configuração manual salva com sucesso!${NC}"
echo "Host configurado: $SUB_DOMAIN"
echo "NS configurado: $NS_DOMAIN"
echo "=========================================="
