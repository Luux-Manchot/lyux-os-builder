#!/usr/bin/env bash
# Script de provisionnement automatique des Clients LyuX (KDE Plasma)
set -euo pipefail

ROLE="${1:-eleve}"
HOSTNAME="${2:-client-lyux}"

echo "======================================================"
echo "💻 Installation du poste client LyuX : $HOSTNAME ($ROLE)"
echo "======================================================"

export DEBIAN_FRONTEND=noninteractive

# 1. Installation de l'environnement graphique KDE Plasma & Outils
apt-get update
apt-get install -y \
    kde-plasma-desktop \
    sddm \
    cifs-utils \
    libpam-mount \
    firefox-esr \
    firefox-esr-l10n-fr \
    libreoffice \
    libreoffice-l10n-fr \
    vlc \
    python3-pyqt6 \
    python3-pip \
    veyon-service

# 2. Si poste prof -> Veyon Master
if [ "$ROLE" = "prof" ]; then
    apt-get install -y veyon-master || true
fi

# 3. Copie des applications LyuX
mkdir -p /opt/lyux/apps
if [ -d "/vagrant/projects" ]; then
    cp -r /vagrant/projects/lyux-welcome /opt/lyux/apps/
    cp -r /vagrant/projects/lyux-report /opt/lyux/apps/
    
    # Raccourcis globaux
    cp /opt/lyux/apps/lyux-welcome/lyux-welcome.desktop /usr/share/applications/
    cp /opt/lyux/apps/lyux-report/lyux-report.desktop /usr/share/applications/
    
    # Autostart pour lyux-welcome
    mkdir -p /etc/xdg/autostart
    cp /opt/lyux/apps/lyux-welcome/lyux-welcome.desktop /etc/xdg/autostart/
fi

systemctl set-default graphical.target
echo "✅ Client LyuX ($HOSTNAME) prêt !"
