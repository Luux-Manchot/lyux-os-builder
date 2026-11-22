#!/usr/bin/env bash
# ==============================================================================
# Script de Capture de l'Image Master LyuX Client depuis LyuX-C14-PC02
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo "📦 Capture de l'image système Master depuis LyuX-C14-PC02"
echo "=========================================================="

MASTER_IP="${LYUX_MASTER_IP:-192.168.10.14}"
: "${LYUX_SSH_PASSWORD:?Définir LYUX_SSH_PASSWORD (ou utiliser un coffre Ansible Vault)}"
PASSWORD="$LYUX_SSH_PASSWORD"
TARGET_DIR="/opt/lyux/golden-master"
OUTPUT_SQUASHFS="/opt/lyux/lyux-master.squashfs"

mkdir -p "$TARGET_DIR"

echo "⏳ Synchronisation du système complet en cours..."
sshpass -p "$PASSWORD" rsync -aAX \
    -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    --numeric-ids \
    --delete \
    --rsync-path="sudo rsync" \
    --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/var/tmp/*","/var/log/*"} \
    "lyux-admin@$MASTER_IP:/" "$TARGET_DIR/"

echo "🧹 Nettoyage des identifiants spécifiques à la machine source..."
# Vider machine-id pour régénération au premier boot
echo "" > "$TARGET_DIR/etc/machine-id" || true
rm -f "$TARGET_DIR/var/lib/dbus/machine-id" || true

# Supprimer les clés d'hôte SSH (elles seront régénérées au boot)
rm -f "$TARGET_DIR/etc/ssh/ssh_host_*" || true

# Supprimer les baux DHCP et connexions résiduelles
rm -f "$TARGET_DIR/var/lib/NetworkManager/*.lease" || true

# Réinitialiser /etc/hostname temporaire
echo "lyux-client" > "$TARGET_DIR/etc/hostname"

echo "🗜️ Compression en SquashFS haute performance (ZSTD)..."
rm -f "$OUTPUT_SQUASHFS"
mksquashfs "$TARGET_DIR" "$OUTPUT_SQUASHFS" -comp zstd -b 1048576 -Xcompression-level 15 -noappend

echo "✅ Image Master générée avec succès : $OUTPUT_SQUASHFS"
ls -lh "$OUTPUT_SQUASHFS"
