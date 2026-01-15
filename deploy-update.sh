#!/bin/bash
# GF-Free Proxy - Script de mise à jour
# Exécuter sur CT 118 (10.10.40.58) en tant que root

set -e

DEPLOY_DIR="/opt/gf-free-proxy"
SOURCE_DIR="$(dirname "$0")"

echo "=== Mise à jour GF-Free Proxy ==="

# Backup config existant
if [ -f "$DEPLOY_DIR/config.py" ]; then
    cp "$DEPLOY_DIR/config.py" "$DEPLOY_DIR/config.py.bak"
    echo "✓ Config sauvegardée"
fi

# Copie des fichiers mis à jour
cp "$SOURCE_DIR/main.py" "$DEPLOY_DIR/"
cp "$SOURCE_DIR/config.example.py" "$DEPLOY_DIR/"
cp "$SOURCE_DIR/gf-free-proxy.service" "$DEPLOY_DIR/"
cp "$SOURCE_DIR/requirements.txt" "$DEPLOY_DIR/"

echo "✓ Fichiers copiés"

# Mise à jour du service systemd
cp "$SOURCE_DIR/gf-free-proxy.service" /etc/systemd/system/
systemctl daemon-reload
echo "✓ Service systemd mis à jour"

# Redémarrage
systemctl restart gf-free-proxy
sleep 2

# Vérification
if systemctl is-active --quiet gf-free-proxy; then
    echo "✓ Service redémarré avec succès"
    curl -s http://localhost:8888/health | python3 -m json.tool
else
    echo "✗ Erreur au démarrage du service"
    journalctl -u gf-free-proxy -n 20 --no-pager
    exit 1
fi

echo ""
echo "=== Mise à jour terminée ==="
