#!/bin/bash
set -e

echo "==============================================="
echo " Netflix-N-Hack - Instalador oficial (venv)"
echo "==============================================="

# =====================================================
# VARIABLES BASE
# =====================================================

BASE_DIR="/home/pi/Netflix-N-Hack"
VENV_DIR="$BASE_DIR/venv"
PAYLOAD_DIR="$BASE_DIR/payloads"
ETAHEN_URL="https://github.com/etaHEN/etaHEN/releases/latest/download/etaHEN.bin"

# =====================================================
# INPUT USUARIO
# =====================================================

read -p "👉 Ingresa la IP de la PS5 (ej: 192.168.1.170): " TARGET_IP

RPI_IP=$(hostname -I | awk '{print $1}')

echo "✔ IP detectada de la Raspberry: $RPI_IP"
echo "✔ IP configurada de la PS5: $TARGET_IP"

# =====================================================
# DEPENDENCIAS SISTEMA
# =====================================================

echo "[*] Instalando dependencias del sistema..."
sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    netcat-openbsd \
    openssl

# =====================================================
# CLONAR REPOSITORIO
# =====================================================

if [ ! -d "$BASE_DIR" ]; then
    echo "[*] Clonando repositorio Netflix-N-Hack..."
    git clone https://github.com/earthonion/Netflix-N-Hack.git "$BASE_DIR"
else
    echo "[*] Repositorio ya existe, se reutiliza"
fi

cd "$BASE_DIR"

# =====================================================
# ENTORNO VIRTUAL
# =====================================================

echo "[*] Creando entorno virtual Python..."
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install mitmproxy websockets

# =====================================================
# PAYLOAD etaHEN
# =====================================================

echo "[*] Descargando etaHEN..."
mkdir -p "$PAYLOAD_DIR"
curl -L "$ETAHEN_URL" -o "$PAYLOAD_DIR/etaHEN.bin"

# =====================================================
# CONFIGURAR IP EN inject.js
# =====================================================

echo "[*] Configurando inject.js..."
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject.js

# =====================================================
# CONFIGURAR IP EN inject_elfldr_automated.js
# =====================================================

echo "[*] Configurando inject_elfldr_automated.js..."
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject_elfldr_automated.js

# =====================================================
# SOBRESCRIBIR proxy.py (COMPLETO, SIN RECORTES)
# =====================================================

echo "[*] Instalando proxy.py (versión completa)..."

cat > "$BASE_DIR/proxy.py" <<EOF
from mitmproxy import http
from mitmproxy.proxy.layers import tls
import os

# =====================================================
# IMPORTS PARA ENVÍO AUTOMÁTICO
# =====================================================
import subprocess
import threading
import time

# =====================================================
# CONFIGURACIÓN DE ENVÍO AUTOMÁTICO
# =====================================================

PAYLOAD_SEND_DELAY = 1
PAYLOAD_BIN_PATH = "/home/pi/Netflix-N-Hack/payloads/etaHEN.bin"
TARGET_IP = "$TARGET_IP"
TARGET_PORT = 9021

# =====================================================
# LOAD BLOCKED DOMAINS
# =====================================================

BLOCKED_DOMAINS = set()

def load_blocked_domains():
    global BLOCKED_DOMAINS
    hosts_path = os.path.join(os.path.dirname(__file__), "hosts.txt")

    try:
        with open(hosts_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split()
                    domain = parts[-1] if parts else line
                    BLOCKED_DOMAINS.add(domain.lower())
        print(f"[+] Loaded {len(BLOCKED_DOMAINS)} blocked domains from hosts.txt")
    except FileNotFoundError:
        print(f"[!] WARNING: hosts.txt not found at {hosts_path}")
    except Exception as e:
        print(f"[!] ERROR loading hosts.txt: {e}")

load_blocked_domains()

def is_blocked(hostname: str) -> bool:
    hostname_lower = hostname.lower()
    for blocked in BLOCKED_DOMAINS:
        if blocked in hostname_lower:
            return True
    return False

# =====================================================
# TLS BLOCKER
# =====================================================

def tls_clienthello(data: tls.ClientHelloData) -> None:
    if data.context.server.address:
        hostname = data.context.server.address[0]
        if is_blocked(hostname):
            raise ConnectionRefusedError(f"[*] Blocked HTTPS connection to: {hostname}")

# =====================================================
# ENVÍO PAYLOAD CON DELAY (NC -N)
# =====================================================

def send_payload_with_delay():
    def worker():
        time.sleep(PAYLOAD_SEND_DELAY)
        cmd = f"cat {PAYLOAD_BIN_PATH} | nc -N {TARGET_IP} {TARGET_PORT}"
        subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    threading.Thread(target=worker, daemon=True).start()

# =====================================================
# MAIN HTTP HANDLER
# =====================================================

def request(flow: http.HTTPFlow) -> None:
    hostname = flow.request.pretty_host
    proxyServerIP = flow.client_conn.sockname[0].encode("UTF-8")

    if "netflix" in hostname:
        flow.response = http.Response.make(
            200, b"uwu", {"Content-Type": "application/x-msl+json"}
        )
        return

    if is_blocked(hostname):
        flow.response = http.Response.make(404, b"uwu")
        return

    base = os.path.dirname(__file__)

    if "/js/common/config/text/config.text.lruderrorpage" in flow.request.path:
        inject_path = os.path.join(base, "inject_elfldr_automated.js")
        with open(inject_path, "rb") as f:
            content = f.read().replace(b"PLS_STOP_HARDCODING_IPS", proxyServerIP)
        flow.response = http.Response.make(200, content, {"Content-Type": "application/javascript"})
        return

    PAYLOAD_MAP = {
        "/js/lapse.js": "payloads/lapse.js",
        "/js/elf_loader.js": "payloads/elf_loader.js",
        "/js/elfldr.elf": "payloads/elfldr.elf",
    }

    for url_path, payload_file in PAYLOAD_MAP.items():
        if url_path in flow.request.path:
            full_path = os.path.join(base, payload_file)
            with open(full_path, "rb") as f:
                content = f.read()

            mime = "application/octet-stream" if payload_file.endswith(".elf") else "application/javascript"
            flow.response = http.Response.make(200, content, {"Content-Type": mime})

            if url_path == "/js/elfldr.elf":
                send_payload_with_delay()
            return
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
# SERVICIOS SYSTEMD
# =====================================================

echo "[*] Creando servicios systemd..."

sudo tee /etc/systemd/system/netflix_mitmproxy.service >/dev/null <<SERVICE
[Unit]
Description=Netflix-N-Hack mitmproxy
After=network.target

[Service]
User=pi
WorkingDirectory=$BASE_DIR
ExecStart=$VENV_DIR/bin/mitmdump -s proxy.py -p 8080
Restart=always
RestartSec=3

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
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable netflix_mitmproxy
sudo systemctl enable netflix_ws

echo "==============================================="
echo " ✅ INSTALACIÓN COMPLETA"
echo " Inicia con:"
echo "   sudo systemctl start netflix_mitmproxy"
echo "   sudo systemctl start netflix_ws"
echo "==============================================="
