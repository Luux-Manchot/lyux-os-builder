#!/usr/bin/env bash
# ==============================================================================
# Installation et Déploiement du Profil Graphique Officiel LyuX (KDE Plasma 6)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Les thèmes sont embarqués dans l'ISO sous ${SCRIPT_DIR}/themes/ pour un rendu
# identique même sans accès réseau lors de l'installation. En fallback (exécution
# directe sur une machine déjà installée), on retombe sur les dépôts amont.
fetch_theme() {
    local name="$1" dest="$2"
    rm -rf "$dest"
    if [ -d "${SCRIPT_DIR}/themes/${name}" ]; then
        echo "   📦 ${name} : depuis le payload embarqué"
        cp -a "${SCRIPT_DIR}/themes/${name}" "$dest"
    else
        echo "   🌐 ${name} : depuis GitHub (payload absent)"
        git clone --depth 1 "https://github.com/vinceliuice/${name}.git" "$dest"
    fi
}

echo "======================================================"
echo "🎨 Déploiement du Thème Graphique Officiel LyuX"
echo "======================================================"

# 1. Dépendances requises
apt-get update -qq
apt-get install -y git curl libglib2.0-bin fonts-inter

# 2. Installation du thème Orchis KDE
if [ ! -d "/usr/share/plasma/look-and-feel/com.github.vinceliuice.Orchis" ]; then
    echo "📦 Installation de Orchis KDE..."
    fetch_theme Orchis-kde /tmp/Orchis-kde
    (cd /tmp/Orchis-kde && ./install.sh)
    rm -rf /tmp/Orchis-kde
fi

# 3. Installation des décorations & fonds d'écran WhiteSur
if [ ! -d "/usr/share/aurorae/themes/WhiteSur-Sharp" ] || [ ! -d "/usr/share/wallpapers/WhiteSur" ]; then
    echo "📦 Installation de WhiteSur (Décorations & Wallpapers)..."
    fetch_theme WhiteSur-kde /tmp/WhiteSur-kde
    (cd /tmp/WhiteSur-kde && ./install.sh -w default sharp)
    rm -rf /tmp/WhiteSur-kde
fi

# 4. Installation des icônes Tela-circle
if [ ! -d "/usr/share/icons/Tela-circle" ]; then
    echo "📦 Installation du pack d'icônes Tela-circle..."
    fetch_theme Tela-circle-icon-theme /tmp/Tela-circle
    (cd /tmp/Tela-circle && ./install.sh -d /usr/share/icons standard)
    rm -rf /tmp/Tela-circle
fi

# 5. Permissions universelles de lecture sur les thèmes et médias
echo "🔒 Ajustement des permissions /usr/share/..."
chmod -R 755 /usr/share/aurorae/themes/Orchis* /usr/share/aurorae/themes/WhiteSur* 2>/dev/null || true
chmod -R 755 /usr/share/plasma/desktoptheme/Orchis* /usr/share/plasma/desktoptheme/WhiteSur* 2>/dev/null || true
chmod -R 755 /usr/share/plasma/look-and-feel/com.github.vinceliuice.* 2>/dev/null || true
chmod -R 755 /usr/share/color-schemes/Orchis*.colors 2>/dev/null || true
chmod -R 755 /usr/share/wallpapers/WhiteSur* /usr/share/wallpapers/Orchis* 2>/dev/null || true
chmod -R 755 /usr/share/icons/Tela-circle* 2>/dev/null || true

# 6. Variables d'environnement KDE / Qt & Menus XDG
mkdir -p /etc/xdg/menus
ln -sf /etc/xdg/menus/plasma-applications.menu /etc/xdg/menus/applications.menu 2>/dev/null || true
touch /etc/environment
grep -qxF "QT_QPA_PLATFORMTHEME=kde" /etc/environment || echo "QT_QPA_PLATFORMTHEME=kde" >> /etc/environment
grep -qxF "XDG_CURRENT_DESKTOP=KDE" /etc/environment || echo "XDG_CURRENT_DESKTOP=KDE" >> /etc/environment

# 7. Configuration Kiosk globale (/etc/xdg/kdeglobals)
echo "🔒 Déploiement des restrictions Kiosk dans /etc/xdg/kdeglobals..."
mkdir -p /etc/xdg
cp "${SCRIPT_DIR}/xdg/kdeglobals" /etc/xdg/kdeglobals
chmod 644 /etc/xdg/kdeglobals

# 8. Démarrage silencieux (Silent Boot) & Écran de chargement Plymouth
echo "🚀 Configuration du démarrage silencieux et de l'écran Plymouth..."
if [ -f "${SCRIPT_DIR}/99-lyux-silent-boot.cfg" ]; then
    mkdir -p /etc/default/grub.d
    cp "${SCRIPT_DIR}/99-lyux-silent-boot.cfg" /etc/default/grub.d/99-lyux-silent-boot.cfg
    chmod 644 /etc/default/grub.d/99-lyux-silent-boot.cfg
fi
echo "kernel.printk = 1 1 1 1" > /etc/sysctl.d/20-quiet-boot.conf
chmod 644 /etc/sysctl.d/20-quiet-boot.conf
sysctl -p /etc/sysctl.d/20-quiet-boot.conf 2>/dev/null || true
apt-get install -y plymouth plymouth-theme-breeze
plymouth-set-default-theme -R breeze
update-grub

# 9. Écran de Connexion SDDM Moderne LyuX
echo "🖥️ Déploiement du thème SDDM LyuX..."
chmod 644 /usr/share/applications/*.desktop 2>/dev/null || true
if [ -d "${SCRIPT_DIR}/sddm/lyux-sddm" ]; then
    mkdir -p /usr/share/sddm/themes/lyux-sddm
    cp -r "${SCRIPT_DIR}/sddm/lyux-sddm/"* /usr/share/sddm/themes/lyux-sddm/
    chmod -R 755 /usr/share/sddm/themes/lyux-sddm
fi
if [ -f "${SCRIPT_DIR}/sddm/99-lyux-theme.conf" ]; then
    mkdir -p /etc/sddm.conf.d
    cp "${SCRIPT_DIR}/sddm/99-lyux-theme.conf" /etc/sddm.conf.d/99-lyux-theme.conf
    chmod 644 /etc/sddm.conf.d/99-lyux-theme.conf
fi
# X11 uniquement : la session Wayland est masquée pour éviter tout retour en arrière.
if [ -f /usr/share/wayland-sessions/plasma.desktop ]; then
    mv /usr/share/wayland-sessions/plasma.desktop /usr/share/wayland-sessions/plasma.desktop.disabled
fi

# 10. Écran de Verrouillage Moderne (KScreenLocker)
echo "🔒 Déploiement du thème d'écran de verrouillage LyuX..."
if [ -d "${SCRIPT_DIR}/lockscreen" ]; then
    mkdir -p /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/assets
    mkdir -p /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/
    
    cp "${SCRIPT_DIR}/lockscreen/LockScreenUi.qml" /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/ 2>/dev/null || true
    cp "${SCRIPT_DIR}/lockscreen/MainBlock.qml" /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/ 2>/dev/null || true
    cp "${SCRIPT_DIR}/lockscreen/UserDelegate.qml" /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/ 2>/dev/null || true
    cp "${SCRIPT_DIR}/lockscreen/ActionButton.qml" /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/ 2>/dev/null || true
    cp "${SCRIPT_DIR}/lockscreen/UserDelegate.qml" /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/ 2>/dev/null || true
    cp "${SCRIPT_DIR}/lockscreen/ActionButton.qml" /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/ 2>/dev/null || true
    
    # Préférer les composants QML sur disque plutôt que les binaires compilés internes
    if [ -f /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/qmldir ]; then
        sed -i '/prefer :/d' /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/qmldir
    fi
    
    if [ -d "${SCRIPT_DIR}/lockscreen/assets" ]; then
        cp -a "${SCRIPT_DIR}/lockscreen/assets/"* /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/assets/ 2>/dev/null || true
    fi
    
    chmod 644 /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/*.qml 2>/dev/null || true
    chmod 644 /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/UserDelegate.qml 2>/dev/null || true
    chmod 644 /usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/breeze/components/ActionButton.qml 2>/dev/null || true
    
    if [ -f "${SCRIPT_DIR}/lockscreen/kscreenlockerrc" ]; then
        mkdir -p /etc/xdg
        cp "${SCRIPT_DIR}/lockscreen/kscreenlockerrc" /etc/xdg/kscreenlockerrc
        chmod 644 /etc/xdg/kscreenlockerrc
    fi
fi

# 10.1 Menu des applications Kickoff personnalisé LyuX
echo "📱 Déploiement du menu des applications Kickoff..."
if [ -d "${SCRIPT_DIR}/kickoff" ]; then
    mkdir -p /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/ui/
    cp "${SCRIPT_DIR}/kickoff/"*.qml /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/ui/ 2>/dev/null || true
    chmod 644 /usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/ui/*.qml 2>/dev/null || true
fi

# 11. Modèle par défaut /etc/skel
echo "📋 Déploiement du modèle utilisateur dans /etc/skel..."
mkdir -p /etc/skel/.config /etc/skel/Bureau
cp -r "${SCRIPT_DIR}/skel/.config/"* /etc/skel/.config/
cp "${SCRIPT_DIR}/skel/Bureau/"* /etc/skel/Bureau/
# Création du raccourci Corbeille avec syntaxe Linux
cat << 'EOF' > /etc/skel/Bureau/trash:∕.desktop
[Desktop Entry]
EmptyIcon=user-trash
Icon=user-trash-full
Name=Corbeille
Type=Link
URL[$e]=trash:/
EOF
rm -f /etc/skel/Bureau/trash.desktop 2>/dev/null || true
chmod -R 755 /etc/skel/.config /etc/skel/Bureau
chmod 755 /etc/skel/Bureau/*.desktop 2>/dev/null || true

# 12. Propagation aux comptes existants (/srv/samba/homes/ et /home/)
echo "👥 Synchronisation des profils existants..."
for USER_DIR in /srv/samba/homes/* /home/*; do
    if [ -d "$USER_DIR" ] && [ "$(basename "$USER_DIR")" != "lost+found" ] && [ ! -L "$USER_DIR" ]; then
        U_NAME=$(basename "$USER_DIR")
        U_GROUP=$(stat -c "%G" "$USER_DIR" 2>/dev/null || echo "$U_NAME")
        
        # Copie de la configuration Plasma et du bureau
        mkdir -p "$USER_DIR/.config" "$USER_DIR/Bureau"
        cp -r "${SCRIPT_DIR}/skel/.config/"* "$USER_DIR/.config/" 2>/dev/null || true
        cp "${SCRIPT_DIR}/skel/Bureau/"* "$USER_DIR/Bureau/" 2>/dev/null || true
        cat << 'EOF' > "$USER_DIR/Bureau/trash:∕.desktop"
[Desktop Entry]
EmptyIcon=user-trash
Icon=user-trash-full
Name=Corbeille
Type=Link
URL[$e]=trash:/
EOF
        rm -f "$USER_DIR/Bureau/trash.desktop" 2>/dev/null || true
        
        # Attribution des droits au propriétaire du compte
        chown -R "${U_NAME}:${U_GROUP}" "$USER_DIR/.config" "$USER_DIR/Bureau" 2>/dev/null || true
        chmod 755 "$USER_DIR/Bureau"/*.desktop 2>/dev/null || true
    fi
done

echo "✅ Profil graphique LyuX déployé avec succès !"
