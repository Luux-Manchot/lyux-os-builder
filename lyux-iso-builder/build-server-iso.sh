#!/usr/bin/env bash
# ==============================================================================
# Script de génération de l'ISO Serveur Appliance LyuX (Debian 12 / Cockpit)
# ==============================================================================
set -euo pipefail

echo "======================================================="
echo "💿 Compilation de l'ISO Serveur Appliance LyuX"
echo "======================================================="

WORK_DIR="/tmp/lyux-server-iso-build"
ISO_NAME="lyux-server-appliance-latest.iso"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/lyux-server/build"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# 1. Image source Debian Netinst officielle (Debian 12.8 / 13)
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
ORIG_ISO="$WORK_DIR/debian-netinst.iso"

if [ ! -f "$ORIG_ISO" ]; then
    echo "⬇️ 1. Téléchargement de l'image source Debian Netinst..."
    curl -Lo "$ORIG_ISO" "$DEBIAN_ISO_URL" || true
fi

# 2. Extraction du contenu de l'ISO
echo "📦 2. Extraction de l'ISO avec xorriso/7z..."
mkdir -p "$WORK_DIR/iso_root"
if command -v 7z >/dev/null 2>&1; then
    7z x "$ORIG_ISO" -o"$WORK_DIR/iso_root" -y >/dev/null
elif command -v xorriso >/dev/null 2>&1; then
    xorriso -osirrox on -indev "$ORIG_ISO" -extract / "$WORK_DIR/iso_root" >/dev/null
fi

# 3. Injection du Preseed Serveur Headless
echo "⚙️ 3. Injection du preseed d'installation automatique..."
cp "$REPO_ROOT/os-builder/lyux-lab-vm/configs/debian_server_preseed_auto.cfg" "$WORK_DIR/iso_root/preseed.cfg"

# 4. Embarquement du module Cockpit LyuX Hub
echo "🐧 4. Embarquement de l'extension Cockpit LyuX Hub..."
mkdir -p "$WORK_DIR/iso_root/lyux-payload/cockpit-lyux"
cp -r "$REPO_ROOT/lyux-server/cockpit-lyux/"* "$WORK_DIR/iso_root/lyux-payload/cockpit-lyux/"

# 5. Configuration Isolinux pour boot 100% automatique
echo "🚀 5. Configuration du menu de démarrage rapide (Zéro question)..."
if [ -f "$WORK_DIR/iso_root/isolinux/isolinux.cfg" ]; then
    cat << 'EOF' > "$WORK_DIR/iso_root/isolinux/txt.cfg"
default install
label install
    menu label ^Installer LyuX Server (Automatique)
    kernel /install.amd/vmlinuz
    append vga=788 initrd=/install.amd/initrd.gz auto=true priority=critical file=/cdrom/preseed.cfg --- quiet
EOF
fi

# 6. Recompilation de l'ISO Hybride UEFI/BIOS
echo "📀 6. Recompilation de l'image ISO bootable finale..."
if command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs \
        -r -V "LYUX_SERVER" \
        -J -l -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot -isohybrid-gpt-basdat \
        -o "$OUTPUT_DIR/$ISO_NAME" \
        "$WORK_DIR/iso_root"
    echo "✅ ISO générée avec succès : $OUTPUT_DIR/$ISO_NAME"
else
    echo "ℹ️ xorriso non présent sur l'hôte, préparation des fichiers terminée dans $WORK_DIR/iso_root."
fi
