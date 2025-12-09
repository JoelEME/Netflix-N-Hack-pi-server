#!/usr/bin/env python3
"""
Downgrader script for CUSA14296
Redirects game update JSON requests to a specific older version.
"""
from mitmproxy import http
from mitmproxy.proxy.layers import tls
import os
import logging

logger = logging.getLogger(__name__)

# Load blocked domains from hosts.txt
BLOCKED_DOMAINS = set()

# Downgrade target for CUSA14296
CUSA14296_REDIRECT = "http://gs2.ww.prod.dl.playstation.net/gs2/ppkgo/prod/CUSA14296_00/82/f_1a8dfab325d77cbcb3d087d9aa8ab574b8cac8d3597d62d10eaaad3469c001df/f/UP4415-CUSA14296_00-0000000000000000-A0209-V0100.json"
TARGET_CUSA = "CUSA14296"


def load_blocked_domains():
    """Load domains from hosts.txt file"""
    global BLOCKED_DOMAINS
    hosts_path = os.path.join(os.path.dirname(__file__), "../hosts.txt")

    try:
        with open(hosts_path, "r") as f:
            for line in f:
                line = line.strip()
                # Skip empty lines and comments
                if line and not line.startswith("#"):
                    # Extract domain (handle format: "0.0.0.0 domain.com" or just "domain.com")
                    parts = line.split()
                    domain = parts[-1] if parts else line
                    BLOCKED_DOMAINS.add(domain.lower())
        logger.info(f"[+] Loaded {len(BLOCKED_DOMAINS)} blocked domains from hosts.txt")
    except FileNotFoundError:
        logger.info(f"[!] WARNING: hosts.txt not found at {hosts_path}")
        exit()
    except Exception as e:
        logger.info(f"[!] ERROR loading hosts.txt: {e}")


# Load domains when script initializes
load_blocked_domains()


def is_blocked(hostname: str) -> bool:
    """Check if hostname matches any blocked domain"""
    hostname_lower = hostname.lower()
    for blocked in BLOCKED_DOMAINS:
        if blocked in hostname_lower:
            return True
    return False


def tls_clienthello(data: tls.ClientHelloData) -> None:
    if data.context.server.address:
        hostname = data.context.server.address[0]

        # Block domains at TLS layer
        if is_blocked(hostname):
            logger.info(f"[*] Blocked HTTPS connection to: {hostname}")
            raise ConnectionRefusedError(f"[*] Blocked HTTPS connection to: {hostname}")
        else:
            data.ignore_connection = True


def request(flow: http.HTTPFlow) -> None:
    """Handle HTTP/HTTPS requests after TLS handshake"""
    hostname = flow.request.pretty_host

    # Check for downgrade redirect (HTTP only)
    if flow.request.scheme == "http" and "gs2.ww.prod.dl.playstation.net" in flow.request.pretty_url:
        if TARGET_CUSA in flow.request.pretty_url and ".json" in flow.request.pretty_url:
            logger.info(f"[REDIRECT][{TARGET_CUSA}] {flow.request.pretty_url}")
            logger.info(f"        -> {CUSA14296_REDIRECT}")
            flow.request.url = CUSA14296_REDIRECT

        elif ".pkg" in flow.request.pretty_url and TARGET_CUSA in flow.request.pretty_url:
            # Allow .pkg downloads for this CUSA
            pass
        else:
            # Corrupt other game update responses
            flow.response = http.Response.make(
                200,
                b"uwu",
                {"Content-Type": "application/x-msl+json"}
            )
            logger.info(f"[*] Corrupted Game update response for: {hostname}")

        return

    # Block other domains from hosts.txt
    if is_blocked(hostname):
        flow.response = http.Response.make(
            404,
            b"uwu",
        )
        logger.info(f"[*] Blocked HTTP request to: {hostname}")
        return
