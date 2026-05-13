#!/bin/bash

# ─────────────────────────────────────────────
#   GHTUN WARZONE - Auto Startup Script
# ─────────────────────────────────────────────

# ── 1. Generate a FRESH UUID every run ────────
UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")

# ── 2. Build SNI / host from Codespace name ───
SNI="${CODESPACE_NAME}-443.app.github.dev"

# ── 3. Write fresh Xray config ────────────────
#    GitHub Codespace acts as TLS terminator,
#    so Xray listens plain on 443 internally.
#    wsSettings.headers.Host must match SNI
#    so GitHub's reverse proxy routes correctly.
cat > /etc/config.json << XRAY_EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/live-chat",
          "headers": {
            "Host": "${SNI}"
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
XRAY_EOF

# ── 4. Stop any old Xray ──────────────────────
pkill -f "xray" 2>/dev/null || true
sleep 1

# ── 5. Start Xray in background ───────────────
nohup /usr/local/bin/xray -c /etc/config.json > /tmp/xray.log 2>&1 &
XRAY_PID=$!
sleep 2

# Check Xray actually started
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
  echo "❌ Xray failed to start! Check /tmp/xray.log"
  cat /tmp/xray.log
  exit 1
fi

# ── 6. Date tag ───────────────────────────────
DATE_TAG=$(date +%Y%m%d-%H%M)

# ── 7. IP list ────────────────────────────────
IPS=("50.7.87.4" "50.7.87.2" "142.54.178.211" "50.7.87.5" "204.12.196.34")

# ── 8. Banner ─────────────────────────────────
echo ""
echo "=================================================="
echo "  🚀  GHTUN WARZONE — VPN CONFIG PANEL"
echo "=================================================="
echo "  UUID : ${UUID}"
echo "  SNI  : ${SNI}"
echo "  PID  : ${XRAY_PID}"
echo "=================================================="
echo ""

# ── 9. GitHub Domain config ───────────────────
echo "--------------------------------------------------"
echo "  🌐  GitHub Domain"
echo "--------------------------------------------------"
echo ""
echo "vless://${UUID}@${SNI}:443?encryption=none&security=tls&sni=${SNI}&host=${SNI}&insecure=0&allowInsecure=0&type=ws&path=%2Flive-chat#Arix-GH-${DATE_TAG}"
echo ""

# ── 10. IP configs ────────────────────────────
echo "--------------------------------------------------"
echo "  📡  Direct IP Configs (Lower Ping)"
echo "--------------------------------------------------"
echo ""

for IP in "${IPS[@]}"; do
  LABEL=$(echo "${IP}" | tr '.' '-')
  echo "  🔹 ${IP}"
  echo "vless://${UUID}@${IP}:443?encryption=none&security=tls&sni=${SNI}&host=${SNI}&insecure=0&allowInsecure=0&type=ws&path=%2Flive-chat#Arix-${LABEL}-${DATE_TAG}"
  echo ""
done

echo "--------------------------------------------------"
echo "  ✅ Xray running (PID: ${XRAY_PID}) | /tmp/xray.log"
echo "--------------------------------------------------"
echo ""
