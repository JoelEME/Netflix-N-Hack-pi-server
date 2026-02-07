#!/bin/bash
set -e

echo "==============================================="
echo " Netflix-N-Hack - Instalador Pi Server (venv)"
echo "==============================================="

# =====================================================
# VARIABLES BASE
# =====================================================

BASE_DIR="/home/pi/Netflix-N-Hack"
VENV_DIR="$BASE_DIR/venv"
PAYLOAD_DIR="$BASE_DIR/payloads"
ETAHEN_API_URL="https://api.github.com/repos/etaHEN/etaHEN/releases/latest"

# =====================================================
# INPUT USUARIO (PIPE SAFE)
# =====================================================

read -p "👉 Ingresa la IP de la PS5 (ej: 192.168.1.170): " TARGET_IP </dev/tty

RPI_IP=$(hostname -I | awk '{print $1}')

echo "✔ IP Raspberry detectada : $RPI_IP"
echo "✔ IP PS5 configurada     : $TARGET_IP"

# =====================================================
# DEPENDENCIAS DEL SISTEMA
# =====================================================

echo "[*] Instalando dependencias del sistema..."
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
# CLONAR REPOSITORIO ORIGINAL
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

echo "[*] Creando entorno virtual..."
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install mitmproxy websockets

# =====================================================
# DESCARGA etaHEN (GITHUB RELEASES)
# =====================================================

echo "[*] Descargando etaHEN (última versión)..."
mkdir -p "$PAYLOAD_DIR"

BIN_URL=$(curl -s "$ETAHEN_API_URL" \
  | grep '"browser_download_url"' \
  | grep '\.bin"' \
  | head -n 1 \
  | cut -d '"' -f 4)

if [ -z "$BIN_URL" ]; then
    echo "❌ No se pudo detectar el binario etaHEN"
    exit 1
fi

echo "✔ Asset detectado:"
echo "  $BIN_URL"

curl -L "$BIN_URL" -o "$PAYLOAD_DIR/etaHEN.bin"

if [ ! -s "$PAYLOAD_DIR/etaHEN.bin" ]; then
    echo "❌ Error: etaHEN.bin vacío"
    exit 1
fi

echo "✔ etaHEN descargado correctamente"

# =====================================================
# MODIFICAR inject.js
# =====================================================

echo "[*] Configurando inject.js..."
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject.js

# =====================================================
# MODIFICAR inject_elfldr_automated.js
# =====================================================

echo "[*] Configurando inject_elfldr_automated.js..."
sed -i "s/PLS_STOP_HARDCODING_IPS/$RPI_IP/g" inject_elfldr_automated.js

# =============================================================================
# SOBRESCRIBIR proxy.py
# =============================================================================

echo "[*] Instalando proxy.py modificado (completo)..."

cat > "$BASE_DIR/proxy.py" <<EOF
from mitmproxy import http
from mitmproxy.proxy.layers import tls
import os

# =====================================================
# BASE DIR
# =====================================================
BASE_DIR = os.path.dirname(__file__)

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
TARGET_IP = "192.168.1.170"
TARGET_PORT = 9021

# =====================================================
# LOAD BLOCKED DOMAINS
# =====================================================

BLOCKED_DOMAINS = set()

def load_blocked_domains():
    global BLOCKED_DOMAINS
    hosts_path = os.path.join(BASE_DIR, "hosts.txt")

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
# TLS BLOCKER (FIX REAL)
# =====================================================

def tls_clienthello(data: tls.ClientHelloData) -> None:
    try:
        if data.context.server.address:
            hostname = data.context.server.address[0]
            if is_blocked(hostname):
                print(f"[*] Blocked HTTPS (TLS) to: {hostname}")
                data.context.server.close()
    except Exception as e:
        print(f"[!] TLS block error: {e}")

# =====================================================
# ENVÍO PAYLOAD CON DELAY (NC -N)
# =====================================================

def send_payload_with_delay():
    def worker():
        time.sleep(PAYLOAD_SEND_DELAY)

        cmd = (
            f"cat {PAYLOAD_BIN_PATH} | "
            f"nc -N {TARGET_IP} {TARGET_PORT}"
        )

        print(f"[*] Ejecutando envío etaHEN → {TARGET_IP}:{TARGET_PORT}")

        subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    threading.Thread(target=worker, daemon=True).start()

# =====================================================
# MAIN HTTP HANDLER
# =====================================================

def request(flow: http.HTTPFlow) -> None:
    hostname = flow.request.pretty_host

    try:
        proxyServerIP = flow.client_conn.sockname[0].encode("UTF-8")
    except Exception:
        proxyServerIP = b"127.0.0.1"

    # NETFLIX BLOCK
    if "netflix" in hostname:
        flow.response = http.Response.make(
            200,
            b"uwu",
            {"Content-Type": "application/x-msl+json"}
        )
        print(f"[*] Corrupted Netflix response for: {hostname}")
        return

    # HOSTS.TXT BLOCK (HTTP)
    if is_blocked(hostname):
        flow.response = http.Response.make(
            404,
            b"uwu",
        )
        print(f"[*] Blocked HTTP request to: {hostname}")
        return

    # inject_elfldr_automated.js
    if "/js/common/config/text/config.text.lruderrorpage" in flow.request.path:
        inject_path = os.path.join(BASE_DIR, "inject_elfldr_automated.js")

        try:
            with open(inject_path, "rb") as f:
                content = f.read().replace(
                    b"PLS_STOP_HARDCODING_IPS",
                    proxyServerIP
                )
            flow.response = http.Response.make(
                200,
                content,
                {"Content-Type": "application/javascript"}
            )
        except FileNotFoundError:
            flow.response = http.Response.make(404, b"Missing inject_elfldr_automated.js")
        return

    # PAYLOADS
    PAYLOAD_MAP = {
        "/js/lapse.js": "payloads/lapse.js",
        "/js/elf_loader.js": "payloads/elf_loader.js",
        "/js/elfldr.elf": "payloads/elfldr.elf",
    }

    for url_path, payload_file in PAYLOAD_MAP.items():
        if url_path in flow.request.path:
            full_path = os.path.join(BASE_DIR, payload_file)
            print(f"[*] Serving payload from: {full_path}")

            try:
                with open(full_path, "rb") as f:
                    content = f.read()

                mime = "application/octet-stream" if payload_file.endswith(".elf") else "application/javascript"

                flow.response = http.Response.make(
                    200,
                    content,
                    {"Content-Type": mime}
                )

                if url_path == "/js/elfldr.elf":
                    print(
                        f"[*] elfldr.elf servido → "
                        f"envío payload en {PAYLOAD_SEND_DELAY}s"
                    )
                    send_payload_with_delay()

            except FileNotFoundError:
                flow.response = http.Response.make(
                    404,
                    f"Missing {payload_file}".encode()
                )
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
# SYSTEMD SERVICES
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
sudo systemctl enable netflix_mitmproxy netflix_ws

# =====================================================
# PROMPT FINAL (SOLO START OPCIONAL)
# =====================================================

read -p "¿Iniciar servicios ahora? (s/n): " RESP </dev/tty

if [[ "$RESP" =~ ^[sS]$ ]]; then
    sudo systemctl start netflix_mitmproxy
    sudo systemctl start netflix_ws
    echo "▶ Servicios INICIADOS ahora"
else
    echo "▶ Servicios habilitados para el próximo reinicio"
fi

echo "==============================================="
echo " ✅ INSTALACIÓN COMPLETA"
echo "==============================================="
