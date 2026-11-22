#!/usr/bin/env bash
# ==============================================================================
# Script de compilation de la VRAIE ISO Autonome LyuX (Type Windows Setup)
# ==============================================================================
set -euo pipefail

echo "================================================================="
echo "💿 Compilation de l'ISO Autonome d'Installation Directe LyuX OS"
echo "================================================================="

BUILD_DIR="/opt/lyux/iso-build"
ISO_ROOT="$BUILD_DIR/root"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/lyux-desktop/build"
ISO_NAME="lyux-client-autonomous-installer.iso"
MASTER_SQUASHFS="/opt/lyux/lyux-master.squashfs"

rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT/live" "$ISO_ROOT/isolinux" "$ISO_ROOT/boot/grub" "$OUTPUT_DIR"

# 1. Copie du Kernel et Initrd avec live-boot
echo "🐧 Extraction du noyau Linux et Initrd officiel live-boot..."
KERNEL_FILE=$(ls -t /boot/vmlinuz-* | head -1)
INITRD_FILE=$(ls -t /boot/initrd.img-* | head -1)

echo "Noyau : $KERNEL_FILE"
echo "Initrd : $INITRD_FILE"

cp "$KERNEL_FILE" "$ISO_ROOT/live/vmlinuz"
cp "$INITRD_FILE" "$ISO_ROOT/live/initrd.img"

# 2. Lien instantané vers l'image système complète Master SquashFS (0 octet dupliqué)
echo "📦 Embarquement de l'image système Master LyuX (Lien direct SquashFS)..."
ln -f "$MASTER_SQUASHFS" "$ISO_ROOT/live/filesystem.squashfs"

# 3. Embarquement du programme d'installation autonome
echo "🛠️ Embarquement de l'assistant d'installation LyuX..."
cp /tmp/lyux-installer.sh "$ISO_ROOT/live/installer.sh"
chmod 755 "$ISO_ROOT/live/installer.sh"

# 4. Configuration Isolinux pour BIOS (Amorçage direct sans prompt)
echo "🚀 Configuration du démarrage automatique BIOS (Isolinux)..."
cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_ROOT/isolinux/" 2>/dev/null || cp /usr/lib/syslinux/modules/bios/isolinux.bin "$ISO_ROOT/isolinux/" || true
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$ISO_ROOT/isolinux/" 2>/dev/null || true
cp /usr/lib/syslinux/modules/bios/libutil.c32 "$ISO_ROOT/isolinux/" 2>/dev/null || true
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$ISO_ROOT/isolinux/" 2>/dev/null || true

cat << 'EOF' > "$ISO_ROOT/isolinux/isolinux.cfg"
default lyux
prompt 0
timeout 10

label lyux
    menu label ^Installer LyuX Client OS (Autonome)
    kernel /live/vmlinuz
    append initrd=/live/initrd.img boot=live components quiet splash
EOF

# 5. Configuration GRUB pour UEFI
echo "🚀 Configuration du démarrage automatique UEFI (GRUB)..."
cat << 'EOF' > "$ISO_ROOT/boot/grub/grub.cfg"
set default="0"
set timeout=1

menuentry "Installer LyuX Client OS (Installation & Configuration)" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd.img
}
EOF

# 6. Compilation finale de l'ISO avec xorriso
echo "📀 Recompilation finale de l'ISO bootable avec xorriso..."
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

echo "================================================================="
echo "✅ Vraie ISO Autonome générée avec succès :"
ls -lh "$OUTPUT_DIR/$ISO_NAME"
echo "================================================================="
