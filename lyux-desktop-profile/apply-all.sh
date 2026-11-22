#!/usr/bin/env bash
set -e

cp /opt/lyux/desktop-profile/xdg/kdeglobals /etc/xdg/kdeglobals
chmod 644 /etc/xdg/kdeglobals

# S'assurer que WhiteSur-Sharp est dans /usr/share/aurorae/themes
if [ -d "/home/lyux-admin/.local/share/aurorae/themes/WhiteSur-Sharp" ]; then
    cp -r /home/lyux-admin/.local/share/aurorae/themes/* /usr/share/aurorae/themes/ 2>/dev/null || true
    chmod -R 755 /usr/share/aurorae/themes/
fi

mkdir -p /etc/skel/.config /etc/skel/Bureau
cp -a /opt/lyux/desktop-profile/skel/.config/. /etc/skel/.config/
cp -a /opt/lyux/desktop-profile/skel/Bureau/. /etc/skel/Bureau/

for USER_DIR in /srv/samba/homes/* /home/*; do
    if [ -d "$USER_DIR" ] && [ "$(basename "$USER_DIR")" != "lost+found" ] && [ ! -L "$USER_DIR" ]; then
        U_NAME=$(basename "$USER_DIR")
        U_GROUP=$(stat -c "%G" "$USER_DIR" 2>/dev/null || echo "$U_NAME")
        mkdir -p "$USER_DIR/.config" "$USER_DIR/Bureau"
        cp -a /opt/lyux/desktop-profile/skel/.config/. "$USER_DIR/.config/" 2>/dev/null || true
        cp -a /opt/lyux/desktop-profile/skel/Bureau/. "$USER_DIR/Bureau/" 2>/dev/null || true
        chown -R "${U_NAME}:${U_GROUP}" "$USER_DIR/.config" "$USER_DIR/Bureau" 2>/dev/null || true
    fi
done

# Recharger kwin et plasmashell pour toute session active
for u in $(loginctl list-users --no-legend | awk '{print $2}'); do
    uid=$(id -u "$u" 2>/dev/null || true)
    if [ -n "$uid" ]; then
        systemctl --user -M "${uid}@" restart plasma-plasmashell.service 2>/dev/null || true
        su - "$u" -c "export DISPLAY=:0; export WAYLAND_DISPLAY=wayland-0; qdbus6 org.kde.KWin /KWin reconfigure" 2>/dev/null || true
    fi
done

echo "OK"
