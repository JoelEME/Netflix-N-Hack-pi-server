#!/bin/bash
set -e

echo "==============================================="
echo " Netflix-N-Hack - Instalador Pi Server"
echo " (PIPE-SAFE · soporta wget | bash)"
echo "==============================================="

# =====================================================
# VARIABLES BASE
# =====================================================

BASE_DIR="/home/pi/Netflix-N-Hack"
VENV_DIR="$BASE_DIR/venv"
PAYLOAD_DIR="$BASE_DIR/payloads"
ETAHEN_API_URL="https://api.github.com/repos/etaHEN/etaHEN/releases/latest"

# =====================================================
# PIPE-SAFE INPUT
# =====================================================

if [ ! -t 0 ]; then
    echo "ℹ Instalación vía pipe detectada (wget | bash)"
fi

RPI_IP=$(hostname -I | awk '{print $1}')
echo "✔ IP Raspberry detectada: $RPI_IP"

while true; do
    read -p "👉 Ingresa la IP de la PS5 (ej: 192.168.1.170): " TARGET_IP </dev/tty
    [[ -n "$TARGET_IP" ]] && break
    echo "❌ IP inválida, intenta nuevamente"
done

echo "✔ IP PS5 configurada: $TARGET_IP"

# =====================================================
# DEPENDENCIAS DEL SISTEMA
# =====================================================

echo "[*] Instalando dependencias..."
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
# CLONAR REPOSITORIO
# =====================================================

if [ ! -d "$BASE_DIR" ]; then
    echo "[*] Clonando Netflix-N-Hack..."
    git clone https://github.com/earthonion/Netflix-N-Hack.git "$BASE_DIR"
else
    echo "[*] Repositorio existente, reutilizando"
fi

cd "$BASE_DIR"

# =====================================================
# ENTORNO VIRTUAL
# =====================================================

echo "[*] Creando entorno virtual..."
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install mitmproxy websockets

# =====================================================
# DESCARGAR etaHEN REAL
# =====================================================

echo "[*] Descargando última versión de etaHEN..."

mkdir -p "$PAYLOAD_DIR"

BIN_URL=$(curl -s "$ETAHEN_API_URL" \
  | grep '"browser_download_url"' \
  | grep '.bin"' \
  | head -n 1 \
  | cut -d '"' -f 4)

if [ -z "$BIN_URL" ]; then
    echo "❌ No se pudo detectar el binario etaHEN"
    exit 1
fi

curl -L "$BIN_URL" -o "$PAYLOAD_DIR/etaHEN.bin"

if [ ! -s "$PAYLOAD_DIR/etaHEN.bin" ]; then
    echo "❌ etaHEN.bin vacío"
    exit 1
fi

echo "✔ etaHEN descargado correctamente"

# =====================================================
# MODIFICAR JS (IP RASPBERRY)
# =====================================================

echo "[*] Configurando inject.js"
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject.js

echo "[*] Configurando inject_elfldr_automated.js"
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject_elfldr_automated.js

# =====================================================
# SOBRESCRIBIR proxy.py (ORIGINAL + CAMBIOS)
# =====================================================

echo "[*] Instalando proxy.py modificado..."

cat > "$BASE_DIR/proxy.py" <<EOF
$(sed "s/TARGET_IP = \".*\"/TARGET_IP = \"$TARGET_IP\"/" <<'PYCODE'
from mitmproxy import http
from mitmproxy.proxy.layers import tls
import os
import subprocess
import threading
import time

PAYLOAD_SEND_DELAY = 1
PAYLOAD_BIN_PATH = "/home/pi/Netflix-N-Hack/payloads/etaHEN.bin"
TARGET_IP = "REPLACED_BY_INSTALLER"
TARGET_PORT = 9021

BLOCKED_DOMAINS = set()

def load_blocked_domains():
    global BLOCKED_DOMAINS
    hosts_path = os.path.join(os.path.dirname(__file__), "hosts.txt")
    try:
        with open(hosts_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    BLOCKED_DOMAINS.add(line.split()[-1].lower())
        print(f"[+] Loaded {len(BLOCKED_DOMAINS)} blocked domains")
    except Exception as e:
        print(f"[!] hosts.txt error: {e}")

load_blocked_domains()

def is_blocked(host):
    return any(b in host.lower() for b in BLOCKED_DOMAINS)

def tls_clienthello(data):
    if data.context.server.address:
        host = data.context.server.address[0]
        if is_blocked(host):
            raise ConnectionRefusedError()

def send_payload_with_delay():
    def worker():
        time.sleep(PAYLOAD_SEND_DELAY)
        subprocess.Popen(
            f"cat {PAYLOAD_BIN_PATH} | nc -N {TARGET_IP} {TARGET_PORT}",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    threading.Thread(target=worker, daemon=True).start()

def request(flow):
    host = flow.request.pretty_host
    ip = flow.client_conn.sockname[0].encode()

    if "netflix" in host:
        flow.response = http.Response.make(200, b"uwu")
        return

    if is_blocked(host):
        flow.response = http.Response.make(404, b"uwu")
        return

    base = os.path.dirname(__file__)

    if "/js/common/config/text/config.text.lruderrorpage" in flow.request.path:
        p = os.path.join(base, "inject_elfldr_automated.js")
        flow.response = http.Response.make(200, open(p,"rb").read().replace(b"PLS_STOP_HARDCODING_IPS", ip))
        return

    if "/js/elfldr.elf" in flow.request.path:
        p = os.path.join(base, "payloads", "elfldr.elf")
        flow.response = http.Response.make(200, open(p,"rb").read())
        send_payload_with_delay()
        return
PYCODE
)
EOF

# =====================================================
# CERTIFICADOS TLS
# =====================================================

if [ ! -f key.pem ]; then
    echo "[*] Generando certificados TLS..."
    openssl req -x509 -newkey rsa:4096 -nodes \
        -keyout key.pem \
        -out cert.pem \
        -days 365 \
        -subj "/CN=localhost"
fi

# =====================================================
# SYSTEMD SERVICES
# =====================================================

sudo tee /etc/systemd/system/netflix_mitmproxy.service >/dev/null <<SERVICE
[Unit]
Description=Netflix-N-Hack mitmproxy
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
Description=Netflix-N-Hack WebSocket
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
# PROMPT FINAL PIPE-SAFE
# =====================================================

read -p "¿Iniciar servicios ahora? (s/n): " RESP </dev/tty

if [[ "$RESP" =~ ^[sS]$ ]]; then
    sudo systemctl start netflix_mitmproxy
    sudo systemctl start netflix_ws

    echo "==============================================="
    echo " ✅ INSTALACIÓN COMPLETA"
    echo " ▶ Servicios INICIADOS ahora"
    echo "==============================================="
else
    echo "==============================================="
    echo " ✅ INSTALACIÓN COMPLETA"
    echo " ▶ Servicios habilitados para el próximo reinicio"
    echo "==============================================="
fi