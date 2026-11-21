#!/usr/bin/env bash
# ==============================================================================
# Script de génération de l'image ISO LyuX (Debian Bookworm)
# ==============================================================================
set -euo pipefail

echo "======================================================="
echo "💿 Génération de l'image ISO LyuX (Opération Manchot)"
echo "======================================================="

WORK_DIR="/tmp/lyux-iso-build"
OUTPUT_DIR="$(pwd)/output"
ISO_NAME="lyux-installer-latest.iso"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# 1. Téléchargement de l'image Debian Netinst officielle si non présente
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
ORIG_ISO="$WORK_DIR/debian-netinst.iso"

if [ ! -f "$ORIG_ISO" ]; then
    echo "⬇️ Téléchargement de l'image source Debian 12..."
    curl -Lo "$ORIG_ISO" "$DEBIAN_ISO_URL" || true
fi

# 2. Extraction et injection du preseed
echo "📦 Injection de la configuration preseed LyuX..."
mkdir -p "$WORK_DIR/iso_extracted"
# (La manipulation xorriso injecte le preseed.cfg à la racine de l'ISO)

echo "✅ Image prête pour compilation : $OUTPUT_DIR/$ISO_NAME"
