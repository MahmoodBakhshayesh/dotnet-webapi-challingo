#!/usr/bin/env bash
# Install temporary IP edge proxy: :80 = production, :81 = staging.
# Prefer GUI → Remote VPS → Domain / publish (real nginx) when you have DNS.
#
# Usage (on VPS, from production server-files/ or any path with scaffold-edge-proxy.py):
#   sudo ./install-edge.sh
#   sudo ./install-edge.sh /path/to/scaffold-edge-proxy.py

set -euo pipefail

SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SRC="$SCRIPT_DIR/scaffold-edge-proxy.py"
fi
if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC" >&2
  exit 1
fi

install -m 755 "$SRC" /opt/scaffold-edge-proxy.py

if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 81/tcp >/dev/null 2>&1 || true
fi

cat >/etc/systemd/system/scaffold-edge.service <<'EOF'
[Unit]
Description=Scaffold temporary edge proxy (prod :80, staging :81)
After=network.target docker.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/scaffold-edge-proxy.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl stop scaffold-edge 2>/dev/null || true
# Free ports only if nothing critical holds them (safe for fresh IP deploys)
fuser -k 80/tcp 2>/dev/null || true
fuser -k 81/tcp 2>/dev/null || true
sleep 1
systemctl enable --now scaffold-edge
sleep 1
systemctl --no-pager --full status scaffold-edge | head -15 || true
echo ""
echo "Edge listening: production http://VPS_IP/  ·  staging http://VPS_IP:81/"
echo "Stop when applying a real domain: systemctl disable --now scaffold-edge"
