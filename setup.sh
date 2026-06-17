#!/bin/bash
if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
fi
# ==========================================
# Color
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'


# Função para perguntar se deseja instalar ou pular a etapa
perguntar_etapa() {
    local servico=$1
    echo -e "\n${CYAN}======================================================${NC}"
    while true; do
        read -p "$(echo -e ${GREEN}"Deseja instalar ${servico}? [S/n] (Enter = Sim): "${NC})" sn
        case $sn in
            [Ss]* | "" ) clear; return 0 ;; # Retorna 0 (sucesso/sim) para executar
            [Nn]* ) echo -e "${ORANGE}--- Pulo selecionado: Ignorando ${servico} ---${NC}"; return 1 ;; # Retorna 1 para pular
            * ) echo -e "${RED}Por favor, responda com S (Sim) ou N (Não/Pular).${NC}";;
        esac
    done
}
# ==========================================
# Link Hosting Kalian Untuk Ssh Vpn
ssh_repo="raw.githubusercontent.com/faizalsalato/ssh/main/ssh"
# Link Hosting Kalian Untuk Sstp
sstp_repo="raw.githubusercontent.com/faizalsalato/ssh/main/sstp"
# Link Hosting Kalian Untuk Ssr
ssr_repo="raw.githubusercontent.com/faizalsalato/ssh/main/ssr"
# Link Hosting Kalian Untuk Shadowsocks
shadowsocks_repo="raw.githubusercontent.com/faizalsalato/ssh/main/shadowsocks"
# Link Hosting Kalian Untuk Wireguard
wireguard_repo="raw.githubusercontent.com/faizalsalato/ssh/main/wireguard"
# Link Hosting Kalian Untuk Xray
xray_repo="raw.githubusercontent.com/faizalsalato/ssh/main/xray"
# Link Hosting Kalian Untuk Ipsec
ipsec_repo="raw.githubusercontent.com/faizalsalato/ssh/main/ipsec"
# Link Hosting Kalian Untuk Backup
backup_repo="raw.githubusercontent.com/faizalsalato/ssh/main/backup"
# Link Hosting Kalian Untuk Websocket
websocket_repo="raw.githubusercontent.com/faizalsalato/ssh/main/websocket"
# Link Hosting Kalian Untuk Ohp
ohp_repo="raw.githubusercontent.com/faizalsalato/ssh/main/ohp"

# Getting
MYIP=$(wget -qO- ipinfo.io/ip);
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )
echo "Checking VPS"
IZIN=$(wget -qO- ipinfo.io/ip);

# fix dns missing
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "nameserver 2001:4860:4860::8888" >> /etc/resolv.conf
echo "nameserver 2606:4700:4700::1111" >> /etc/resolv.conf



mkdir /var/lib/crot;
echo "IP=" >> /var/lib/crot/ipvps.conf

perguntar_etapa() {
    local servico="$1"

    echo -e "\n${CYAN}======================================================${NC}"

    while true; do
        read -p "$(echo -e ${GREEN}"Deseja instalar ${servico}? [S/n] (Enter = Sim): "${NC})" sn
        case $sn in
            [Ss]* | "" ) clear; return 0 ;;
            [Nn]* ) echo -e "${ORANGE}--- Pulo selecionado: Ignorando ${servico} ---${NC}"; return 1 ;;
            * ) echo -e "${RED}Por favor, responda com S (Sim) ou N (Não/Pular).${NC}" ;;
        esac
    done
}

# Instalar Host
if perguntar_etapa "Host"; then
    wget https://${ssh_repo}/slhost.sh && chmod +x slhost.sh && ./slhost.sh
fi

# Instalar Xray
if perguntar_etapa "Xray"; then
    wget https://${xray_repo}/ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
fi

# Instalar SSH OVPN
if perguntar_etapa "SSH OVPN"; then
    wget https://${ssh_repo}/ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh
fi

# Instalar SSTP
if perguntar_etapa "SSTP"; then
    wget https://${sstp_repo}/sstp.sh && chmod +x sstp.sh && ./sstp.sh
fi

# Instalar SSR
if perguntar_etapa "SSR"; then
    wget https://${ssr_repo}/ssr.sh && chmod +x ssr.sh && ./ssr.sh
fi

# Instalar Shadowsocks
if perguntar_etapa "Shadowsocks"; then
    wget https://${shadowsocks_repo}/sodosok.sh && chmod +x sodosok.sh && ./sodosok.sh
fi

# Instalar WireGuard
if perguntar_etapa "WireGuard"; then
    wget https://${wireguard_repo}/wg.sh && chmod +x wg.sh && ./wg.sh
fi

# Instalar L2TP/IPSec
if perguntar_etapa "L2TP/IPSec"; then
    wget https://${ipsec_repo}/ipsec.sh && chmod +x ipsec.sh && ./ipsec.sh
fi

# Instalar Backup
if perguntar_etapa "Backup"; then
    wget https://${backup_repo}/set-br.sh && chmod +x set-br.sh && ./set-br.sh
fi

# Instalar WebSocket
if perguntar_etapa "WebSocket"; then
    wget https://${websocket_repo}/edu.sh && chmod +x edu.sh && ./edu.sh
fi

# Instalar OHP Server
if perguntar_etapa "OHP Server"; then
    wget https://${ohp_repo}/ohp.sh && chmod +x ohp.sh && ./ohp.sh
fi

# Instalar SlowDNS
if perguntar_etapa "SlowDNS"; then
    wget https://raw.githubusercontent.com/leitura/slowdns/main/install \
        && chmod +x install \
        && ./install
fi

# Informações de IP e Portas
if perguntar_etapa "IP Saya"; then
    wget https://raw.githubusercontent.com/faizalsalato/ssh/main/ipsaya.sh \
        && chmod +x ipsaya.sh
fi

# Instalar SL-GRPC
if perguntar_etapa "SL-GRPC"; then
    wget https://raw.githubusercontent.com/faizalsalato/ssh/main/grpc/sl-grpc.sh \
        && chmod +x sl-grpc.sh \
        && screen -dmS sl-grpc ./sl-grpc.sh
fi

# Instalar XRAY-GRPC
if perguntar_etapa "XRAY-GRPC"; then
    wget https://raw.githubusercontent.com/faizalsalato/ssh/main/grpc/xray-grpc.sh \
        && chmod +x xray-grpc.sh \
        && screen -dmS xray-grpc ./xray-grpc.sh
fi

# Instalar Shadowsocks Plugin
if perguntar_etapa "Shadowsocks Plugin"; then
    wget https://raw.githubusercontent.com/faizalsalato/ssh/main/shadowsocks-plugin/install-ss-plugin.sh \
        && chmod +x install-ss-plugin.sh \
        && ./install-ss-plugin.sh
fi

rm -f /root/ssh-vpn.sh
rm -f /root/sstp.sh
rm -f /root/wg.sh
rm -f /root/ss.sh
rm -f /root/ssr.sh
rm -f /root/ins-xray.sh
rm -f /root/ipsec.sh
rm -f /root/set-br.sh
rm -f /root/edu.sh
rm -f /root/ohp.sh
rm -f /root/install
rm -f /root/sl-grpc.sh
rm -f /root/install-sldns
rm -f /root/install-ss-plugin.sh
cat <<EOF> /etc/systemd/system/autosett.service
[Unit]
Description=autosetting
Documentation=nekopoi.care

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/set.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable autosett
wget -O /etc/set.sh "https://${ssh_repo}/set.sh"
chmod +x /etc/set.sh
history -c
echo "1.2" > /home/ver
echo " "
echo "Installation has been completed!!"echo " "
echo "============================================================================" | tee -a log-install.txt
echo "" | tee -a log-install.txt
echo "----------------------------------------------------------------------------" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - SlowDNS SSH             : ALL Port SSH"  | tee -a log-install.txt
echo "   - OpenSSH                 : 22, 2253"  | tee -a log-install.txt
echo "   - OpenVPN                 : TCP 1194, UDP 2200, SSL 990"  | tee -a log-install.txt
echo "   - Stunnel5                : 443, 445"  | tee -a log-install.txt
echo "   - Dropbear                : 443, 109, 143"  | tee -a log-install.txt
echo "   - CloudFront Websocket    : "  | tee -a log-install.txt
echo "   - SSH Websocket TLS       : 443"  | tee -a log-install.txt
echo "   - SSH Websocket HTTP      : 8880"  | tee -a log-install.txt
echo "   - Websocket OpenVPN       : 2086"  | tee -a log-install.txt
echo "   - Squid Proxy             : 3128, 8000"  | tee -a log-install.txt
echo "   - Badvpn                  : 7100, 7200, 7300"  | tee -a log-install.txt
echo "   - Nginx                   : 89"  | tee -a log-install.txt
echo "   - Wireguard               : 7070"  | tee -a log-install.txt
echo "   - L2TP/IPSEC VPN          : 1701"  | tee -a log-install.txt
echo "   - PPTP VPN                : 1732"  | tee -a log-install.txt
echo "   - SSTP VPN                : 444"  | tee -a log-install.txt
echo "   - Shadowsocks-R           : 1443-1543"  | tee -a log-install.txt
echo "   - SS-OBFS TLS             : 2443-2543"  | tee -a log-install.txt
echo "   - SS-OBFS HTTP            : 3443-3543"  | tee -a log-install.txt
echo "   - XRAYS Vmess TLS         : 8443"  | tee -a log-install.txt
echo "   - XRAYS Vmess None TLS    : 80"  | tee -a log-install.txt
echo "   - XRAYS Vless TLS         : 8443"  | tee -a log-install.txt
echo "   - XRAYS Vless None TLS    : 80"  | tee -a log-install.txt
echo "   - XRAYS Trojan            : 2083"  | tee -a log-install.txt
echo "   - XRAYS VMESS GRPC        : 1180"  | tee -a log-install.txt
echo "   - XRAYS VLESS GRPC        : 2280"  | tee -a log-install.txt
echo "   - OHP SSH                 : 8181"  | tee -a log-install.txt
echo "   - OHP Dropbear            : 8282"  | tee -a log-install.txt
echo "   - OHP OpenVPN             : 8383"  | tee -a log-install.txt
echo "   - TrojanGo                : 2087"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Server Information & Other Features"  | tee -a log-install.txt
echo "   - Timezone                : Asia/Kuala_Lumpur (GMT +8)"  | tee -a log-install.txt
echo "   - Fail2Ban                : [ON]"  | tee -a log-install.txt
echo "   - Dflate                  : [ON]"  | tee -a log-install.txt
echo "   - IPtables                : [ON]"  | tee -a log-install.txt
echo "   - Auto-Reboot             : [ON]"  | tee -a log-install.txt
echo "   - IPv6                    : [OFF]"  | tee -a log-install.txt
echo "   - Autoreboot On 05.00 GMT +8" | tee -a log-install.txt
echo "   - Autobackup Data" | tee -a log-install.txt
echo "   - Restore Data" | tee -a log-install.txt
echo "   - Auto Delete Expired Account" | tee -a log-install.txt
echo "   - Full Orders For Various Services" | tee -a log-install.txt
echo "   - White Label" | tee -a log-install.txt
echo "   - Installation Log --> /root/log-install.txt"  | tee -a log-install.txt
echo ""
echo ""
echo " Reboot 15 Sec"
sleep 15
reboot
