# Diretório Local (adicione no topo do seu script principal se já não tiver)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Copiar arquivos localmente em vez de baixar
cp "${SCRIPT_DIR}/websocket/ws-tls.service" /etc/systemd/system/ws-tls.service
chmod +x /etc/systemd/system/ws-tls.service

cp "${SCRIPT_DIR}/websocket/ws-tls" /usr/local/bin/ws-tls
chmod +x /usr/local/bin/ws-tls

# Assumindo que você tenha uma pasta stunnel5 localmente
cp "${SCRIPT_DIR}/stunnel5/stunnel5.conf" /etc/stunnel5/stunnel5.conf

# Settings SSLH
cat > /etc/default/sslh <<-END
# Default options for sslh initscript
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 0.0.0.0:443 --ssl 127.0.0.1:777 --ssh 127.0.0.1:109 --openvpn 127.0.0.1:1194 --http 127.0.0.1:8880 --pidfile /var/run/sslh/sslh.pid -n"
END

# Recarregar e Reiniciar Serviços
systemctl daemon-reload
systemctl enable ws-tls
systemctl restart ws-tls

systemctl enable sslh
systemctl restart sslh
systemctl status sslh --no-pager