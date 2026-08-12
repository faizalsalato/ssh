<p align="center">

<h2 align="center">
🚀 Auto Script Install All VPN Service
<br>Mod By blaylook
<br><img src="https://img.shields.io/badge/Release-v2.1-blue.svg">
<img src="https://img.shields.io/badge/API-REST-green.svg">
<img src="https://img.shields.io/badge/Protocolos-12-orange.svg">
</h2>

</p>

---

## 📋 Índice

- [Instalação Rápida](#-instalação-rápida)
- [API REST](#-api-rest-12-protocolos)
- [OpenVPN UDP 53](#-openvpn-udp-53-ultra-rápido)
- [Painel de Controle](#-painel-de-controle-menu)
- [Serviços & Portas](#-serviços--portas)
- [Sistema Suportado](#-sistema-suportado)
- [Troubleshooting](#-troubleshooting)

---

## ⚡ Instalação Rápida

### Instalador Completo (14 serviços)
```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
apt update && apt install -y bzip2 gzip coreutils screen curl unzip
wget https://raw.githubusercontent.com/faizalsalato/ssh/main/setup.sh
chmod +x setup.sh
screen -S setup ./setup.sh
```

### Modo Automático
```bash
bash install.sh --all
```

### Modo Dry-Run (simulação)
```bash
bash install.sh --dry-run
```

---

## 🔌 API REST (12 Protocolos)

API completa para gerenciamento remoto de contas VPN/SSH.

### Instalação da API
```bash
export API_KEY="sua_chave_super_secreta"
bash <(curl -sL https://raw.githubusercontent.com/faizalsalato/ssh/main/api/install.sh)
```

### Endpoints

| Método | Rota | Descrição |
|--------|------|-----------|
| `POST` | `/:proto` | Criar conta |
| `DELETE` | `/:proto/:login` | Deletar conta |
| `POST` | `/:proto/:login/renew` | Renovar conta |
| `GET` | `/:proto` | Listar contas |
| `GET` | `/:proto/:login` | Checar conta |
| `GET` | `/health` | Health check |

### Protocolos Disponíveis

| Protocolo | `:proto` | Auth |
|-----------|----------|------|
| SSH + OpenVPN | `ssh` | login + senha |
| Xray Vmess WS | `vmess` | login |
| Xray Vless WS | `vless` | login |
| Xray Trojan WS | `trojan` | login |
| Trojan-Go | `trgo` | login |
| Shadowsocks | `ss` | login + senha |
| ShadowsocksR | `ssr` | login + senha |
| WireGuard | `wg` | login |
| L2TP/IPSec | `l2tp` | login + senha |
| PPTP | `pptp` | login + senha |
| SSTP | `sstp` | login + senha |
| Xray gRPC | `grpc` | login |

### Exemplos

```bash
# Criar SSH
curl -X POST http://IP:3000/ssh \
  -H 'x-api-key: MINHA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{"login":"cliente","pass":"senha123","dias":30}'

# Criar WireGuard (gera keys automaticamente)
curl -X POST http://IP:3000/wg \
  -H 'x-api-key: MINHA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{"login":"cliente","dias":30}'

# Criar Vmess
curl -X POST http://IP:3000/vmess \
  -H 'x-api-key: MINHA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{"login":"cliente","dias":30}'

# Listar contas SSH
curl http://IP:3000/ssh -H 'x-api-key: MINHA_CHAVE'

# Deletar conta
curl -X DELETE http://IP:3000/wg/cliente -H 'x-api-key: MINHA_CHAVE'

# Renovar conta
curl -X POST http://IP:3000/ssh/cliente/renew \
  -H 'x-api-key: MINHA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{"dias":15}'
```

---

## 🚀 OpenVPN UDP 53 Ultra-Rápido

Script standalone para instalar OpenVPN na porta 53 em qualquer Linux.

### Instalação (1 comando)
```bash
bash <(curl -sL https://raw.githubusercontent.com/faizalsalato/ssh/main/udp53.sh)
```

### Features
- ✅ Compatível com Ubuntu, Debian, CentOS, Fedora
- ✅ Libera porta 53 automaticamente (systemd-resolved, dnsmasq, bind)
- ✅ Gera certificados válidos por 10 anos
- ✅ Configura firewall + NAT automaticamente
- ✅ Serviço systemd com auto-restart
- ✅ Gera `.ovpn` do cliente automaticamente

### Download do cliente
```
http://SEU_IP:89/udp53.ovpn
```

---

## 🎛️ Painel de Controle (menu)

```bash
menu
```

- 🔄 Loop infinito (só sai com `x`)
- 📝 Log de auditoria em `/var/log/vpn-menu.log`
- ✅ Validação de entrada
- ⚠️ Confirmação para ações perigosas (reboot)

---

## 📡 Serviços & Portas

| Serviço | Porta | Status |
|---------|-------|--------|
| OpenSSH | 22, 2253 | ✅ |
| Dropbear | 443, 109, 143 | ✅ |
| Stunnel5 | 443, 445, 777 | ✅ |
| OpenVPN TCP | 1194 | ✅ |
| OpenVPN UDP | 2200 | ✅ |
| OpenVPN UDP 53 | 53 | ✅ |
| OpenVPN SSL | 990 | ✅ |
| WebSocket TLS | 443 | ✅ |
| WebSocket HTTP | 8880 | ✅ |
| WebSocket OVPN | 2086 | ✅ |
| Squid Proxy | 3128, 8080 | ✅ |
| BadVPN UDPGW | 7100, 7200, 7300 | ✅ |
| Nginx (download) | 89 | ✅ |
| WireGuard | 7070 | ✅ |
| L2TP/IPSec | 1701 | ✅ |
| PPTP | 1732 | ✅ |
| SSTP | 444 | ✅ |
| Shadowsocks-R | 1443-1543 | ✅ |
| SS-OBFS TLS | 2443-2543 | ✅ |
| SS-OBFS HTTP | 3443-3543 | ✅ |
| Xray Vmess TLS | 8443 | ✅ |
| Xray Vmess NoTLS | 80 | ✅ |
| Xray Vless TLS | 8443 | ✅ |
| Xray Vless NoTLS | 80 | ✅ |
| Xray Trojan | 2083 | ✅ |
| Xray gRPC | 1180, 3380 | ✅ |
| Trojan-Go | 2087 | ✅ |
| OHP SSH | 8181 | ✅ |
| OHP Dropbear | 8282 | ✅ |
| OHP OpenVPN | 8383 | ✅ |
| SlowDNS | All SSH | ✅ |
| SSLH Multiplex | 443 | ✅ |
| **API REST** | **3000** | ✅ |

---

## 💻 Sistema Suportado

| OS | Versão |
|----|--------|
| Debian | 9, 10, 11, 12 |
| Ubuntu | 18.04, 20.04, 22.04, 24.04 |
| CentOS | 7, 8, 9 |

> ⚠️ Mínimo 1 GB RAM recomendado

---

## 🔧 Troubleshooting

### Fix SSLH Error
```bash
systemctl stop ws-tls
echo sslh:x:109:114::/nonexistent:/usr/sbin/nologin >> /etc/passwd
systemctl start sslh
/etc/init.d/sslh restart
systemctl start ws-tls
reboot
```

### Fix OpenVPN UDP 53
```bash
systemctl status openvpn-udp53
journalctl -u openvpn-udp53 -n 30
ss -ulnp | grep :53
```

### Fix API
```bash
pm2 logs api-ssl
pm2 restart api-ssl --update-env
```

### Websocket Info
- WebSocket precisa de domínio/subdomínio apontado no Cloudflare (CDN)
- Sem domínio não é possível usar bugs do Cloudflare

---

## 📂 Estrutura do Repositório

```
├── install.sh          # Instalador principal v2.1
├── setup.sh            # Entry point rápido
├── udp53.sh            # OpenVPN UDP 53 standalone
├── config.env          # Configurações centralizadas
├── server.js           # API REST (12 protocolos)
├── menu.sh             # Painel de controle
├── api/
│   ├── server.js       # API REST (cópia)
│   ├── install.sh      # Instalador da API (PM2 + npm)
│   └── sakaru*         # Wrappers não-interativos (1-12)
├── ssh/
│   ├── menu.sh         # Painel de controle
│   ├── addssh.sh       # Criar SSH
│   ├── delssh.sh       # Deletar SSH
│   └── renewssh.sh     # Renovar SSH
└── lib/                # Bibliotecas (colors, logger, checker, downloader)
```

---

<p align="center">
<img height=21 src="https://komarev.com/ghpvc/?username=faizalsalato">
<br>
<sub>v2.1 • 12 protocolos • API REST • OpenVPN UDP53</sub>
</p>
