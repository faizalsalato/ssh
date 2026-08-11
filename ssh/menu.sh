#!/bin/bash
# ============================================================
# menu.sh - Painel de Controle VPN (v2 - com validacao + log)
# ============================================================
# Digite 'x' para sair | Log: /var/log/vpn-menu.log
# ============================================================

export PATH="/usr/sbin:/usr/bin:/bin:$PATH"
LOG="/var/log/vpn-menu.log"

m="\033[0;1;36m"
y="\033[0;1;37m"
yy="\033[0;1;32m"
yl="\033[0;1;33m"
wh="\033[0m"
rd="\033[0;1;31m"

# ── Log ──
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OP=$1 | USER=${USER:-root}" >> "$LOG"
}

# ── Confirma acoes perigosas ──
confirm_danger() {
    local msg="${1:-Tem certeza?}"
    echo -e "${rd}⚠ $msg${wh}"
    read -p "Digite 'sim' para confirmar: " resp
    [[ "$resp" == "sim" ]] && return 0 || return 1
}

# ── Executa comando com validacao ──
do_cmd() {
    local name="$1"
    local dangerous="${2:-0}"
    
    # Check if command exists
    if ! command -v "$name" &>/dev/null; then
        echo -e "${rd}✗ Comando '$name' nao encontrado!${wh}"
        sleep 2
        return 1
    fi
    
    # Confirmation for dangerous ops
    if [[ "$dangerous" == "1" ]]; then
        confirm_danger "Esta operacao e perigosa!" || return 1
    fi
    
    log_action "$name"
    "$name"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo -e "${yl}⚠ Comando '$name' retornou codigo $rc${wh}"
    fi
    return $rc
}

show_menu() {
    clear
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$y             Telegram : jembot $wh"
    echo -e "$y           Premium Auto Script By jembot $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "          ${m}v2.0 - Loop + Validacao + Log${wh}"
    echo ""
    echo -e "$y SSH & OpenVPN $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 1$y. Criar Conta SSH & OpenVPN"
    echo -e "$yy 2$y. Gerar Conta Trial SSH"
    echo -e "$yy 3$y. Renovar Conta SSH & OpenVPN"
    echo -e "$yy 4$y. Checar Login SSH & OpenVPN"
    echo -e "$yy 5$y. Listar Membros SSH & OpenVPN"
    echo -e "$yy 6$y. Deletar Conta SSH & OpenVPN"
    echo -e "$yy 7$y. Deletar Contas Expiradas SSH"
    echo -e "$yy 8$y. Configurar Autokill SSH"
    echo -e "$yy 9$y. Verificar Multi-Login SSH"
    echo -e "$yy 10$y. Reiniciar Todos Servicos"
    echo ""
    echo -e "$y L2TP $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 11$y. Criar L2TP          $yy 12$y. Deletar L2TP          $yy 13$y. Renovar L2TP"
    echo ""
    echo -e "$y PPTP $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 14$y. Criar PPTP          $yy 15$y. Deletar PPTP          $yy 16$y. Renovar PPTP"
    echo ""
    echo -e "$y SSTP $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 17$y. Criar SSTP          $yy 18$y. Deletar SSTP          $yy 19$y. Renovar SSTP         $yy 20$y. Checar SSTP"
    echo ""
    echo -e "$y WIREGUARD $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 21$y. Criar Wireguard     $yy 22$y. Deletar Wireguard     $yy 23$y. Renovar Wireguard"
    echo ""
    echo -e "$y SHADOWSOCKS $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 24$y. Criar SS            $yy 25$y. Deletar SS            $yy 26$y. Renovar SS            $yy 27$y. Checar SS"
    echo ""
    echo -e "$y SHADOWSOCKSR $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 28$y. Criar SSR           $yy 29$y. Deletar SSR           $yy 30$y. Renovar SSR           $yy 31$y. Menu SSR"
    echo ""
    echo -e "$y XRAYS / VMESS $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 32$y. Criar Vmess         $yy 33$y. Deletar Vmess         $yy 34$y. Renovar Vmess         $yy 35$y. Checar Vmess         $yy 36$y. Certificado"
    echo ""
    echo -e "$y XRAYS / VLESS $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 37$y. Criar Vless         $yy 38$y. Deletar Vless         $yy 39$y. Renovar Vless         $yy 40$y. Checar Vless"
    echo ""
    echo -e "$y XRAYS / TROJAN $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 41$y. Criar Trojan        $yy 42$y. Deletar Trojan        $yy 43$y. Renovar Trojan        $yy 44$y. Checar Trojan"
    echo ""
    echo -e "$y TROJAN GO $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 45$y. Criar TrojanGo      $yy 46$y. Deletar TrojanGo      $yy 47$y. Renovar TrojanGo      $yy 48$y. Checar TrojanGo"
    echo ""
    echo -e "$y SISTEMA $wh"
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yy 49$y. Add/Change Subdomain    $yy 50$y. Change Port             $yy 51$y. Autobackup"
    echo -e "$yy 52$y. Backup VPS              $yy 53$y. Restore VPS             $yy 54$y. Webmin Menu"
    echo -e "$yy 55$y. Limitar Banda           $yy 56$y. Uso de RAM              $yy 57$y. ${rd}Reboot VPS${wh}"
    echo -e "$yy 58$y. Speedtest               $yy 59$y. Info Sistema            $yy 60$y. Sobre"
    echo ""
    echo -e "$y-------------------------------------------------------------$wh"
    echo -e "$yl  x$y. Sair do Menu                     ${m}l$y. Ver Log de Auditoria${wh}"
    echo ""
}

# ── Mapa de comandos ──
CMD_MAP=(
    "addssh:0"        # 1
    "trialssh:0"      # 2
    "renewssh:0"      # 3
    "cekssh:0"        # 4
    "member:0"        # 5
    "delssh:0"        # 6
    "delexp:0"        # 7
    "autokill:0"      # 8
    "ceklim:0"        # 9
    "restart:1"       # 10 - perigoso
    "addl2tp:0"       # 11
    "dell2tp:0"       # 12
    "renewl2tp:0"     # 13
    "addpptp:0"       # 14
    "delpptp:0"       # 15
    "renewpptp:0"     # 16
    "addsstp:0"       # 17
    "delsstp:0"       # 18
    "renewsstp:0"     # 19
    "ceksstp:0"       # 20
    "addwg:0"         # 21
    "delwg:0"         # 22
    "renewwg:0"       # 23
    "addss:0"         # 24
    "delss:0"         # 25
    "renewss:0"       # 26
    "cekss:0"         # 27
    "addssr:0"        # 28
    "delssr:0"        # 29
    "renewssr:0"      # 30
    "ssr:0"           # 31
    "addvmess:0"      # 32
    "delvmess:0"      # 33
    "renewvmess:0"    # 34
    "cekvmess:0"      # 35
    "certv2ray:0"     # 36
    "addvless:0"      # 37
    "delvless:0"      # 38
    "renewvless:0"    # 39
    "cekvless:0"      # 40
    "addtrojan:0"     # 41
    "deltrojan:0"     # 42
    "renewtrojan:0"   # 43
    "cektrojan:0"     # 44
    "addtrgo:0"       # 45
    "deltrgo:0"       # 46
    "renewtrgo:0"     # 47
    "cektrgo:0"       # 48
    "addhost:0"       # 49
    "changeport:0"    # 50
    "autobackup:0"    # 51
    "backup:0"        # 52
    "restore:1"       # 53 - perigoso
    "wbmn:0"          # 54
    "limitspeed:0"    # 55
    "ram:0"           # 56
    "reboot:1"        # 57 - perigoso
    "speedtest:0"     # 58
    "info:0"          # 59
    "about:0"         # 60
)

# ── Loop principal ──
while true; do
    show_menu
    read -p "Selecione [1-60], [l] para log, ou [x] para sair: " menu
    echo ""
    
    case $menu in
        l|L)
            echo -e "${m}=== Ultimas 20 acoes do menu ===${wh}"
            tail -20 "$LOG" 2>/dev/null || echo "Nenhum log encontrado."
            ;;
        x|X|exit|quit|sair)
            echo -e "$yy Saindo... Ate logo! $wh"
            exit 0
            ;;
        '')
            # Empty input - just loop
            ;;
        *)
            # Validate numeric 1-60
            if [[ "$menu" =~ ^[0-9]+$ ]] && [ "$menu" -ge 1 ] && [ "$menu" -le 60 ]; then
                idx=$((menu - 1))
                entry="${CMD_MAP[$idx]}"
                cmd="${entry%%:*}"
                dangerous="${entry##*:}"
                do_cmd "$cmd" "$dangerous"
            else
                echo -e "${rd}✗ Opcao invalida! Digite 1-60, 'l' para log, ou 'x' para sair.${wh}"
                sleep 1
            fi
            ;;
    esac
    
    echo ""
    read -p "Pressione ENTER para voltar ao menu..." dummy
done
