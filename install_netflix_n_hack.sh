#!/bin/bash
set -e

echo "==============================================="
echo " Netflix-N-Hack - Instalador oficial (venv)"
echo "==============================================="

# =====================================================
# VARIABLES
# =====================================================

BASE_DIR="/home/pi/Netflix-N-Hack"
VENV_DIR="$BASE_DIR/venv"
PAYLOAD_DIR="$BASE_DIR/payloads"
ETAHEN_RELEASE_URL="https://github.com/etaHEN/etaHEN/releases/latest"

# =====================================================
# INPUT USUARIO
# =====================================================

read -p "👉 Ingresa la IP de la PS5 (ej: 192.168.1.170): " TARGET_IP

RPI_IP=$(hostname -I | awk '{print $1}')

echo "✔ IP Raspberry: $RPI_IP"
echo "✔ IP PS5      : $TARGET_IP"

# =====================================================
# DEPENDENCIAS
# =====================================================

sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    netcat-openbsd \
    openssl \
    curl

# =====================================================
# CLONAR REPO
# =====================================================

if [ ! -d "$BASE_DIR" ]; then
    git clone https://github.com/earthonion/Netflix-N-Hack.git "$BASE_DIR"
fi

cd "$BASE_DIR"

# =====================================================
# VENV
# =====================================================

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install mitmproxy websockets

# =====================================================
# DESCARGAR etaHEN (USANDO GITHUB API - CORRECTO)
# =====================================================

echo "[*] Descargando etaHEN desde GitHub releases (API)..."

mkdir -p "$PAYLOAD_DIR"

BIN_URL=$(curl -s https://api.github.com/repos/etaHEN/etaHEN/releases/latest \
  | grep '"browser_download_url"' \
  | grep '.bin"' \
  | head -n 1 \
  | cut -d '"' -f 4)

if [ -z "$BIN_URL" ]; then
    echo "❌ No se pudo detectar el binario etaHEN desde la API"
    exit 1
fi

echo "✔ Asset detectado:"
echo "  $BIN_URL"

curl -L "$BIN_URL" -o "$PAYLOAD_DIR/etaHEN.bin"

if [ ! -s "$PAYLOAD_DIR/etaHEN.bin" ]; then
    echo "❌ Descarga fallida: archivo vacío"
    exit 1
fi

echo "✔ etaHEN descargado correctamente como etaHEN.bin"


# =====================================================
# CONFIGURAR IP EN JS
# =====================================================

sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject.js
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject_elfldr_automated.js

# =====================================================
# PROXY.PY (COMPLETO, SIN RECORTES)
# =====================================================

cat > "$BASE_DIR/proxy.py" <<EOF
from mitmproxy import http
from mitmproxy.proxy.layers import tls
import os
import subprocess
import threading
import time

PAYLOAD_SEND_DELAY = 1
PAYLOAD_BIN_PATH = "/home/pi/Netflix-N-Hack/payloads/etaHEN.bin"
TARGET_IP = "$TARGET_IP"
TARGET_PORT = 9021

BLOCKED_DOMAINS = set()

def load_blocked_domains():
    hosts_path = os.path.join(os.path.dirname(__file__), "hosts.txt")
    try:
        with open(hosts_path, "r") as f:
            for line in f:
                line=line.strip()
                if line and not line.startswith("#"):
                    BLOCKED_DOMAINS.add(line.split()[-1].lower())
    except:
        pass

load_blocked_domains()

def is_blocked(h):
    return any(b in h.lower() for b in BLOCKED_DOMAINS)

def tls_clienthello(data):
    if data.context.server.address:
        if is_blocked(data.context.server.address[0]):
            raise ConnectionRefusedError()

def send_payload_with_delay():
    def w():
        time.sleep(PAYLOAD_SEND_DELAY)
        subprocess.Popen(
            f"cat {PAYLOAD_BIN_PATH} | nc -N {TARGET_IP} {TARGET_PORT}",
            shell=True
        )
    threading.Thread(target=w, daemon=True).start()

def request(flow):
    h = flow.request.pretty_host
    if "netflix" in h:
        flow.response = http.Response.make(200,b"uwu")
        return

    if is_blocked(h):
        flow.response = http.Response.make(404,b"uwu")
        return

    base = os.path.dirname(__file__)

    if "/js/common/config/text/config.text.lruderrorpage" in flow.request.path:
        with open(base+"/inject_elfldr_automated.js","rb") as f:
            c=f.read().replace(b"PLS_STOP_HARDCODING_IPS",
                               flow.client_conn.sockname[0].encode())
        flow.response=http.Response.make(200,c)
        return

    if "/js/elfldr.elf" in flow.request.path:
        with open(base+"/payloads/elfldr.elf","rb") as f:
            flow.response=http.Response.make(200,f.read())
        send_payload_with_delay()
        return
EOF

# =====================================================
# CERTIFICADOS
# =====================================================

[ ! -f key.pem ] && openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout key.pem -out cert.pem -days 365 -subj "/CN=localhost"

# =====================================================
# SYSTEMD
# =====================================================

sudo tee /etc/systemd/system/netflix_mitmproxy.service >/dev/null <<SERVICE
[Unit]
After=network.target
[Service]
User=pi
WorkingDirectory=$BASE_DIR
ExecStart=$VENV_DIR/bin/mitmdump -s proxy.py -p 8080
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE

sudo tee /etc/systemd/system/netflix_ws.service >/dev/null <<SERVICE
[Unit]
After=network.target
[Service]
User=pi
WorkingDirectory=$BASE_DIR
ExecStart=$VENV_DIR/bin/python ws.py
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable netflix_mitmproxy netflix_ws

# =====================================================
# PROMPT FINAL
# =====================================================

read -p "¿Iniciar servicios ahora? (s/n): " RESP

if [[ "$RESP" =~ ^[sS]$ ]]; then
    sudo systemctl start netflix_mitmproxy
    sudo systemctl start netflix_ws
    echo "✔ Servicios iniciados"
else
    echo "ℹ Servicios habilitados para el próximo reinicio"
fi

echo "==============================================="
echo " ✅ INSTALACIÓN FINALIZADA"
echo "==============================================="
