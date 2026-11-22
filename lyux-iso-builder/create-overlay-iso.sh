#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "⚙️ Création de l'overlay live et recompilation de l'ISO Autonome"
echo "================================================================="

OVERLAY_DIR="/tmp/live-overlay"
ISO_ROOT="/opt/lyux/iso-build/root"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/lyux-desktop/build"
ISO_NAME="lyux-client-autonomous-installer.iso"

rm -rf "$OVERLAY_DIR"
mkdir -p "$OVERLAY_DIR/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$OVERLAY_DIR/usr/local/bin"
mkdir -p "$OVERLAY_DIR/usr/bin"
mkdir -p "$OVERLAY_DIR/bin"
mkdir -p "$OVERLAY_DIR/root"
mkdir -p "$OVERLAY_DIR/etc"

# 1. Copie directe de l'installateur dans /usr/local/bin
cp /tmp/lyux-installer.sh "$OVERLAY_DIR/usr/local/bin/lyux-installer"
chmod 755 "$OVERLAY_DIR/usr/local/bin/lyux-installer"

# 2. Intégration indispensable de unsquashfs dans le Live
if [ -f "/usr/bin/unsquashfs" ]; then
    cp /usr/bin/unsquashfs "$OVERLAY_DIR/usr/bin/unsquashfs"
    cp /usr/bin/unsquashfs "$OVERLAY_DIR/bin/unsquashfs"
    cp /usr/bin/unsquashfs "$OVERLAY_DIR/usr/local/bin/unsquashfs"
    chmod 755 "$OVERLAY_DIR/usr/bin/unsquashfs" "$OVERLAY_DIR/bin/unsquashfs" "$OVERLAY_DIR/usr/local/bin/unsquashfs"
fi

# 2b. Machine-id valide pour que systemd, D-Bus et NetworkManager démarrent sans erreur
mkdir -p "$OVERLAY_DIR/var/lib/dbus"
UUID_HEX=$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32 || echo "b1a2c3d4e5f60718293a4b5c6d7e8f90")
echo "$UUID_HEX" > "$OVERLAY_DIR/etc/machine-id"
cp "$OVERLAY_DIR/etc/machine-id" "$OVERLAY_DIR/var/lib/dbus/machine-id"

# 3. Vider fstab dans le Live pour supprimer le timeout de 90s sur le disque original
cat << 'EOF' > "$OVERLAY_DIR/etc/fstab"
# LyuX Live fstab
tmpfs /tmp tmpfs nosuid,nodev 0 0
EOF

# Masquer explicitement le swap fantôme du golden master
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/dev-disk-by\x2duuid-4ef165ab\x2d2c93\x2d45a2\x2da24a\x2d4148ada3be04.swap" 2>/dev/null || true
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/dev-sda5.swap" 2>/dev/null || true

# 4. Service Systemd dédié pour lancer l'installateur directement sur /dev/tty1
mkdir -p "$OVERLAY_DIR/etc/systemd/system/multi-user.target.wants"
cat << 'EOF' > "$OVERLAY_DIR/etc/systemd/system/lyux-installer.service"
[Unit]
Description=LyuX Client Autonomous Installer
After=basic.target
Conflicts=getty@tty1.service plymouth-start.service

[Service]
Type=idle
ExecStart=/usr/local/bin/lyux-installer
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/lyux-installer.service "$OVERLAY_DIR/etc/systemd/system/multi-user.target.wants/lyux-installer.service"

# 5. Lancement de l'installateur LyuX au login console en secours
cat << 'EOF' > "$OVERLAY_DIR/root/.profile"
if [ -z "$INSTALLER_RAN" ]; then
    export INSTALLER_RAN=1
    clear
    if [ -x /usr/local/bin/lyux-installer ]; then
        /usr/local/bin/lyux-installer
    elif [ -f /run/live/medium/live/installer.sh ]; then
        bash /run/live/medium/live/installer.sh
    fi
    echo ""
    echo "=================================================="
    echo "=== Console de secours LyuX Client             ==="
    echo "Pour relancer l'assistant : /usr/local/bin/lyux-installer"
    echo "=================================================="
fi
EOF

cp "$OVERLAY_DIR/root/.profile" "$OVERLAY_DIR/root/.bash_profile"
cp "$OVERLAY_DIR/root/.profile" "$OVERLAY_DIR/root/.bashrc"

# 6. Masquer explicitement Plymouth, getty@tty1, display-manager et VirtualBox pour écran propre et affichage direct
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/getty@tty1.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/plymouth-start.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/plymouth.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/plymouth-quit.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/plymouth-quit-wait.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/vboxadd.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/vboxadd-service.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/sddm.service"
ln -sf /dev/null "$OVERLAY_DIR/etc/systemd/system/display-manager.service"

# 7. Compilation de l'overlay squashfs
# IMPORTANT: Nommé zz-installer.squashfs pour se trier APRÈS filesystem.squashfs,
# ce qui garantit qu'il est monté en TOP LAYER au-dessus de filesystem.squashfs par Debian live-boot!
rm -f "$ISO_ROOT/live/"*installer*.squashfs
mksquashfs "$OVERLAY_DIR" "$ISO_ROOT/live/zz-installer.squashfs" -comp zstd -noappend
chmod 644 "$ISO_ROOT/live/zz-installer.squashfs"

# 8. Copie du script d'installation dans l'ISO également
cp /tmp/lyux-installer.sh "$ISO_ROOT/live/installer.sh"
chmod 755 "$ISO_ROOT/live/installer.sh"

# Configuration du bootloader : désactivation complète de Plymouth et priorité tty0
sed -i 's|append initrd=/live/initrd.img boot=live components.*|append initrd=/live/initrd.img boot=live components noprompt quiet plymouth.enable=0 console=tty0 console=ttyS0,115200n8|g' "$ISO_ROOT/isolinux/isolinux.cfg" 2>/dev/null || true
if [ -f "$ISO_ROOT/boot/grub/grub.cfg" ]; then
    sed -i 's|boot=live components.*|boot=live components noprompt quiet plymouth.enable=0 console=tty0 console=ttyS0,115200n8|g' "$ISO_ROOT/boot/grub/grub.cfg" 2>/dev/null || true
fi

# 9. Recompilation de l'ISO hybride
rm -f "$OUTPUT_DIR/$ISO_NAME"

MBR_TEMPLATE=""
if [ -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]; then
    MBR_TEMPLATE="-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin"
fi

xorriso -as mkisofs \
    -r -V "LYUX_INSTALL" \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    $MBR_TEMPLATE \
    -o "$OUTPUT_DIR/$ISO_NAME" \
    "$ISO_ROOT"

chmod 644 "$OUTPUT_DIR/$ISO_NAME"
echo "✅ ISO autonome recompilée avec succès avec zz-installer.squashfs en TOP layer !"
ls -lh "$OUTPUT_DIR/$ISO_NAME"
