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

mkdir -p /var/tmp
WORK_DIR="/var/tmp/lyux-client-iso-build"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_ARG="${1:-${LYUX_ISO_VERSION:-}}"
if [ -z "$VERSION_ARG" ] && [ -f "$REPO_ROOT/lyux-desktop/VERSION" ]; then
    VERSION_ARG="$(tr -d '[:space:]' < "$REPO_ROOT/lyux-desktop/VERSION")"
fi
LYUX_ISO_VERSION="${VERSION_ARG:-0.5.0-beta.1}"
ISO_NAME="lyux-desktop-${LYUX_ISO_VERSION}.iso"
RELEASE_DIR="$REPO_ROOT/lyux-desktop/releases/$LYUX_ISO_VERSION"
OUTPUT_DIR="$REPO_ROOT/lyux-desktop/build"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR" "$RELEASE_DIR"
rm -f "$OUTPUT_DIR/$ISO_NAME" "$OUTPUT_DIR/lyux-client-installer-latest.iso" "$RELEASE_DIR/$ISO_NAME"

# Le preseed doit être vérifié avant injection dans l'ISO.
PRESEED_SOURCE="$REPO_ROOT/os-builder/lyux-iso-builder/preseed/preseed.cfg"
for preseed_token in 'netcfg/enable boolean true' 'netcfg/choose_interface select auto' 'netcfg/disable_autoconfig boolean false' 'netcfg/disable_dhcp boolean false' 'apt-setup/use_mirror boolean true' 'apt-setup/another boolean false' 'apt-setup/cdrom/another boolean false' 'apt-setup/cdrom/set-first boolean true' 'pkgsel/upgrade select none'; do
    grep -qF "$preseed_token" "$PRESEED_SOURCE" || {
        echo "ERREUR : preseed ISO incomplet : $preseed_token" >&2
        exit 1
    }
 done

# 1. Image source Debian 13 Trixie Netinst
# LYUX_DEBIAN_ISO permet de fournir une image locale déjà validée.
# Ne pas réutiliser l'ancien os-builder/lyux-lab-vm/iso/debian-netinst.iso (Debian 12).
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.8.0-amd64-netinst.iso"
ORIG_ISO="${LYUX_DEBIAN_ISO:-/var/tmp/debian-netinst-13.8.0.iso}"
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
cp "$PRESEED_SOURCE" "$WORK_DIR/iso_root/preseed.cfg"
sed -i 's/\r$//' "$WORK_DIR/iso_root/preseed.cfg"

# Mot de passe admin temporaire : fourni par l'exploitant ou généré à chaque build.
# Jamais de valeur fixe dans le dépôt ; changement imposé par l'OOBE au premier boot.
if [ -z "${LYUX_ADMIN_PASSWORD:-}" ]; then
    LYUX_ADMIN_PASSWORD=""
    password_chars='A-Za-z0-9!@#'
    password_len=${#password_chars}
    for ((i = 0; i < 16; i++)); do
        random_byte="$(od -An -N1 -tu1 /dev/urandom | tr -d '[:space:]')"
        LYUX_ADMIN_PASSWORD+="${password_chars:random_byte % password_len:1}"
    done
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
find "$WORK_DIR/iso_root/lyux-payload" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.service' -o -name '*.timer' \) -exec sed -i 's/\r$//' {} +
find "$WORK_DIR/iso_root/lyux-payload" -type f -name '*.sh' -exec chmod +x {} +

# 4b. Profil graphique générique LyuX et thèmes de base embarqués.
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
find "$WORK_DIR/iso_root/lyux-payload" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.service' -o -name '*.timer' \) -exec sed -i 's/\r$//' {} +
find "$WORK_DIR/iso_root/lyux-payload" -type f -name '*.sh' -exec chmod +x {} +

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
        -o "$RELEASE_DIR/$ISO_NAME" \
        "$WORK_DIR/iso_root"
    cp "$RELEASE_DIR/$ISO_NAME" "$OUTPUT_DIR/lyux-client-installer-latest.iso"
    python3 "$REPO_ROOT/os-builder/lyux-iso-builder/publish_release.py" --version "$LYUX_ISO_VERSION" --channel "${LYUX_CHANNEL:-beta}" --iso "$RELEASE_DIR/$ISO_NAME"
    echo "✅ ISO Client générée et versionnée : $RELEASE_DIR/$ISO_NAME"
else
    echo "⚠️ xorriso non disponible."
fi
