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

# 3. Suppression du centre de bienvenue KDE par défaut & Configuration XDG menus
apt-get purge -y plasma-welcome || true
mkdir -p /etc/xdg/autostart
echo "Hidden=true" >> /etc/xdg/autostart/org.kde.plasma-welcome.desktop 2>/dev/null || true
ln -sf /etc/xdg/menus/plasma-applications.menu /etc/xdg/menus/applications.menu 2>/dev/null || true
echo "QT_QPA_PLATFORMTHEME=kde" >> /etc/environment 2>/dev/null || true
echo "XDG_CURRENT_DESKTOP=KDE" >> /etc/environment 2>/dev/null || true

# Session Plasma X11 par défaut (stabilité matérielle et Veyon)
mkdir -p /etc/sddm.conf.d /var/lib/sddm
echo -e "[Users]\nDefaultSession=plasmax11.desktop" > /etc/sddm.conf.d/10-session.conf
chmod 644 /etc/sddm.conf.d/10-session.conf
mv /usr/share/wayland-sessions/plasma.desktop /usr/share/wayland-sessions/plasma.desktop.disabled 2>/dev/null || true

# 4. Copie des applications LyuX
mkdir -p /opt/lyux/apps
if [ -d "/vagrant/projects" ]; then
    cp -r /vagrant/lyux-desktop/applications/welcome /opt/lyux/apps/
    cp -r /vagrant/lyux-desktop/applications/report /opt/lyux/apps/
    
    # Raccourcis globaux
    cp /opt/lyux/apps/welcome/lyux-welcome.desktop /usr/share/applications/
    cp /opt/lyux/apps/report/lyux-report.desktop /usr/share/applications/
    
    # Autostart pour lyux-welcome
    mkdir -p /etc/xdg/autostart
    cp /opt/lyux/apps/welcome/lyux-welcome.desktop /etc/xdg/autostart/
fi

# 5. Déploiement du Profil Graphique officiel LyuX (Thème, Kiosk, Bureau)
if [ -f "/vagrant/os-builder/lyux-desktop-profile/install-desktop-profile.sh" ]; then
    bash /vagrant/os-builder/lyux-desktop-profile/install-desktop-profile.sh || true
fi

systemctl set-default graphical.target
echo "✅ Client LyuX ($HOSTNAME) prêt !"
