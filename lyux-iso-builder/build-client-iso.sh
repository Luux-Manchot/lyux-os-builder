#!/usr/bin/env bash
# ==============================================================================
# Script de génération de l'ISO Client LyuX (Debian 12 / KDE Plasma / Enrôlement)
# ==============================================================================
set -euo pipefail

echo "======================================================="
echo "💿 Compilation de l'ISO Client LyuX (Poste Élève / Prof)"
echo "======================================================="

WORK_DIR="/tmp/lyux-client-iso-build"
ISO_NAME="lyux-client-installer-latest.iso"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/lyux-desktop/build"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# 1. Image source Debian Netinst
ORIG_ISO="/tmp/debian-netinst.iso"
if [ ! -f "$ORIG_ISO" ]; then
    if [ -f "$REPO_ROOT/os-builder/lyux-lab-vm/iso/debian-netinst.iso" ]; then
        cp "$REPO_ROOT/os-builder/lyux-lab-vm/iso/debian-netinst.iso" "$ORIG_ISO"
    else
        echo "⬇️ Téléchargement image Debian Netinst..."
        curl -Lo "$ORIG_ISO" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso" || true
    fi
fi

# 2. Extraction du contenu de l'ISO
echo "📦 Extraction du contenu de l'ISO..."
rm -rf "$WORK_DIR/iso_root"
mkdir -p "$WORK_DIR/iso_root"
if command -v 7z >/dev/null 2>&1; then
    7z x "$ORIG_ISO" -o"$WORK_DIR/iso_root" -y >/dev/null
elif command -v xorriso >/dev/null 2>&1; then
    xorriso -osirrox on -indev "$ORIG_ISO" -extract / "$WORK_DIR/iso_root" >/dev/null
fi

# 3. Injection du Preseed Client
echo "⚙️ Injection du preseed d'installation client..."
cp "$REPO_ROOT/os-builder/lyux-iso-builder/preseed/preseed.cfg" "$WORK_DIR/iso_root/preseed.cfg"

# 4. Embarquement des payloads applicatifs LyuX
echo "🐧 Embarquement des applications client (LyuX Enrollment & Welcome)..."
mkdir -p "$WORK_DIR/iso_root/lyux-payload/enrollment"
mkdir -p "$WORK_DIR/iso_root/lyux-payload/welcome"
cp -r "$REPO_ROOT/lyux-desktop/applications/enrollment/"* "$WORK_DIR/iso_root/lyux-payload/enrollment/" 2>/dev/null || true
cp -r "$REPO_ROOT/lyux-desktop/applications/welcome/"* "$WORK_DIR/iso_root/lyux-payload/welcome/" 2>/dev/null || true

# 5. Configuration Isolinux pour démarrage d'installation
echo "🚀 Configuration du menu Isolinux bootable..."
if [ -f "$WORK_DIR/iso_root/isolinux/isolinux.cfg" ]; then
    cat << 'EOF' > "$WORK_DIR/iso_root/isolinux/txt.cfg"
default install
label install
    menu label ^Installer LyuX Client OS (Enrolement Poste)
    kernel /install.amd/vmlinuz
    append vga=788 initrd=/install.amd/initrd.gz auto=true priority=critical file=/cdrom/preseed.cfg --- quiet
EOF
fi

# 6. Recompilation de l'image ISO avec xorriso
echo "📀 Recompilation de l'image ISO bootable finale..."
if command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs \
        -r -V "LYUX_CLIENT" \
        -J -l -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot -isohybrid-gpt-basdat \
        -o "$OUTPUT_DIR/$ISO_NAME" \
        "$WORK_DIR/iso_root"
    echo "✅ ISO Client générée avec succès : $OUTPUT_DIR/$ISO_NAME"
else
    echo "⚠️ xorriso non disponible."
fi
