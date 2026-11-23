#!/usr/bin/env bash
# ==============================================================================
# Script de génération de l'ISO Client LyuX (Debian 13 / KDE Plasma / Enrôlement)
# ==============================================================================
set -euo pipefail

for tool in xorriso curl git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERREUR : $tool est requis pour generer l'ISO (apt install xorriso curl git)." >&2
        exit 1
    fi
done

echo "======================================================="
echo "💿 Compilation de l'ISO Client LyuX (Poste Élève / Prof)"
echo "======================================================="

WORK_DIR="/tmp/lyux-client-iso-build"
ISO_NAME="lyux-client-installer-latest.iso"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/lyux-desktop/build"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# 1. Image source Debian 13 Trixie Netinst
# LYUX_DEBIAN_ISO permet de fournir une image locale déjà validée.
# Ne pas réutiliser l'ancien os-builder/lyux-lab-vm/iso/debian-netinst.iso (Debian 12).
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.8.0-amd64-netinst.iso"
ORIG_ISO="${LYUX_DEBIAN_ISO:-/tmp/debian-netinst-13.8.0.iso}"
if [ ! -f "$ORIG_ISO" ]; then
    echo "⬇️ Téléchargement de $DEBIAN_ISO_URL ..."
    curl -fL -o "$ORIG_ISO" "$DEBIAN_ISO_URL"
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

# Mot de passe admin temporaire : fourni par l'exploitant ou généré à chaque build.
# Jamais de valeur fixe dans le dépôt ; changement imposé par l'OOBE au premier boot.
if [ -z "${LYUX_ADMIN_PASSWORD:-}" ]; then
    LYUX_ADMIN_PASSWORD="$(tr -dc 'A-Za-z0-9!@#' < /dev/urandom | head -c 16)"
fi
sed -i "s|@@LYUX_ADMIN_PASSWORD@@|$LYUX_ADMIN_PASSWORD|g" "$WORK_DIR/iso_root/preseed.cfg"
echo "⚠️  Mot de passe admin temporaire (à changer au 1er boot) : $LYUX_ADMIN_PASSWORD"

# Proxy apt de l'établissement, optionnel (ex: http://192.168.10.1:3142).
LYUX_APT_PROXY="${LYUX_APT_PROXY:-}"
sed -i "s|@@LYUX_APT_PROXY@@|$LYUX_APT_PROXY|g" "$WORK_DIR/iso_root/preseed.cfg"

# 4. Embarquement des payloads applicatifs LyuX
echo "🐧 Embarquement des applications client (LyuX Enrollment & Welcome)..."
mkdir -p "$WORK_DIR/iso_root/lyux-payload/enrollment"
mkdir -p "$WORK_DIR/iso_root/lyux-payload/welcome"
cp -r "$REPO_ROOT/lyux-desktop/applications/enrollment/"* "$WORK_DIR/iso_root/lyux-payload/enrollment/" 2>/dev/null || true
cp -r "$REPO_ROOT/lyux-desktop/applications/welcome/"* "$WORK_DIR/iso_root/lyux-payload/welcome/" 2>/dev/null || true

# 4b. Visuel OBLIGATOIRE : profil graphique LyuX + thèmes embarqués.
# Le rendu doit être identique dès l'installation, même sans réseau dans
# l'établissement : les thèmes amont sont donc copiés dans l'ISO au build.
PROFILE_PAYLOAD="$WORK_DIR/iso_root/lyux-payload/desktop-profile"
echo "🎨 Embarquement du profil graphique LyuX (SDDM/KDE/lockscreen/Kickoff)..."
mkdir -p "$PROFILE_PAYLOAD"
cp -r "$REPO_ROOT/os-builder/lyux-desktop-profile/." "$PROFILE_PAYLOAD/"
mkdir -p "$PROFILE_PAYLOAD/themes"
for theme in Orchis-kde WhiteSur-kde Tela-circle-icon-theme; do
    echo "   ⬇️  $theme..."
    git clone --depth 1 "https://github.com/vinceliuice/${theme}.git" "$PROFILE_PAYLOAD/themes/$theme"
    rm -rf "$PROFILE_PAYLOAD/themes/$theme/.git"
done

# 5. Configuration Isolinux & GRUB pour démarrage automatique (Zéro question)
echo "🚀 Configuration du démarrage automatique (Isolinux BIOS & GRUB EFI)..."
if [ -d "$WORK_DIR/iso_root/isolinux" ]; then
    cat << 'EOF' > "$WORK_DIR/iso_root/isolinux/isolinux.cfg"
# LyuX Client Installer
default install
prompt 0
timeout 10

label install
    menu label ^Installer LyuX Client OS (Enrolement Poste)
    kernel /install.amd/vmlinuz
    append vga=788 initrd=/install.amd/gtk/initrd.gz auto=true priority=critical file=/cdrom/preseed.cfg debian-installer/locale=fr_FR.UTF-8 console-setup/layoutcode=fr keyboard-configuration/xkb-keymap=fr --- quiet
EOF
fi

if [ -f "$WORK_DIR/iso_root/boot/grub/grub.cfg" ]; then
    cat << 'EOF' > "$WORK_DIR/iso_root/boot/grub/grub.cfg"
set default="0"
set timeout=1

menuentry 'Installer LyuX Client OS (Automatique)' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 auto=true priority=critical file=/cdrom/preseed.cfg debian-installer/locale=fr_FR.UTF-8 console-setup/layoutcode=fr keyboard-configuration/xkb-keymap=fr --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
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
