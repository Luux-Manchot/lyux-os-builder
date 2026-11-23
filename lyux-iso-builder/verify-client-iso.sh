#!/usr/bin/env bash
# ==============================================================================
# Vérification de l'ISO client LyuX : boot, payloads, visuel, zéro secret figé.
# Usage : ./verify-client-iso.sh [chemin/vers/lyux-client-installer-latest.iso]
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ISO="${1:-$REPO_ROOT/lyux-desktop/build/lyux-client-installer-latest.iso}"
FAIL=0

if ! command -v xorriso >/dev/null 2>&1; then
    echo "ERREUR : xorriso requis (apt install xorriso)." >&2
    exit 1
fi
if [ ! -f "$ISO" ]; then
    echo "ERREUR : ISO introuvable : $ISO" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "🔍 Vérification de $ISO"
xorriso -indev "$ISO" -find / -print 2>/dev/null > "$TMP_DIR/files.lst" || true

check_path() {
    if grep -qF "$1" "$TMP_DIR/files.lst"; then
        echo "  ✅ $1"
    else
        echo "  ❌ MANQUANT : $1"
        FAIL=1
    fi
}

echo "--- Amorçage ---"
check_path /isolinux/isolinux.bin
check_path /boot/grub/efi.img
check_path /preseed.cfg

echo "--- Applications OOBE ---"
check_path /lyux-payload/enrollment/src/enroll.py
check_path /lyux-payload/enrollment/systemd/lyux-enrollment.service
check_path /lyux-payload/welcome

echo "--- Visuel obligatoire (profil graphique LyuX) ---"
check_path /lyux-payload/desktop-profile/install-desktop-profile.sh
check_path /lyux-payload/desktop-profile/sddm/lyux-sddm/Main.qml
check_path /lyux-payload/desktop-profile/sddm/99-lyux-theme.conf
check_path /lyux-payload/desktop-profile/lockscreen/LockScreenUi.qml
check_path /lyux-payload/desktop-profile/kickoff/NormalPage.qml
check_path /lyux-payload/desktop-profile/skel/.config/kdeglobals
check_path /lyux-payload/desktop-profile/themes/Orchis-kde
check_path /lyux-payload/desktop-profile/themes/WhiteSur-kde
check_path /lyux-payload/desktop-profile/themes/Tela-circle-icon-theme

echo "--- Contenu du preseed (sécurité) ---"
xorriso -osirrox on -indev "$ISO" -extract /preseed.cfg "$TMP_DIR/preseed.cfg" 2>/dev/null || true
for secret in LyuxDeploy2026 LyuX@2026 '192.168.10.' '192.168.100.' '@@' 'chage -d 0'; do
    if grep -qF "$secret" "$TMP_DIR/preseed.cfg"; then
        echo "  ❌ Valeur figée résiduelle dans le preseed : $secret"
        FAIL=1
    else
        echo "  ✅ Absent : $secret"
    fi
done
grep -qF 'install-desktop-profile.sh' "$TMP_DIR/preseed.cfg" \
    && echo "  ✅ late_command applique le profil graphique" \
    || { echo "  ❌ late_command n'applique pas le profil graphique"; FAIL=1; }

echo "--- SDDM / X11 ---"
xorriso -osirrox on -indev "$ISO" \
    -extract /lyux-payload/desktop-profile/sddm/99-lyux-theme.conf "$TMP_DIR/sddm.conf" 2>/dev/null || true
for token in 'Current=lyux-sddm' 'DisplayServer=x11' 'DefaultSession=plasmax11.desktop'; do
    if grep -qF "$token" "$TMP_DIR/sddm.conf"; then
        echo "  ✅ $token"
    else
        echo "  ❌ Manquant dans 99-lyux-theme.conf : $token"
        FAIL=1
    fi
done

SIZE="$(stat -c%s "$ISO")"
if [ "$SIZE" -gt 500000000 ]; then
    echo "  ✅ Taille ISO : $((SIZE / 1024 / 1024)) Mo"
else
    echo "  ❌ ISO anormalement petite : $SIZE octets"
    FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
    echo "❌ Vérification ÉCHOUÉE." >&2
    exit 1
fi
echo "✅ ISO client conforme (boot + apps + visuel + zéro secret figé)."
