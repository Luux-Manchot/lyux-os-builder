#!/bin/bash
# ==============================================================================
# Script d'installation et de sécurisation des clefs d'authentification Veyon
# Opération Manchot (LyuX) - Milestone 4
# ==============================================================================
set -euo pipefail

IS_TEACHER=false
if [ "${1:-}" = "--teacher" ] || [ "${IS_TEACHER_PC:-false}" = "true" ]; then
    IS_TEACHER=true
fi

# Création du groupe enseignants s'il n'existe pas
if ! getent group enseignants >/dev/null 2>&1; then
    groupadd -r enseignants || true
fi

# 1. Configuration de l'arborescence publique (tous les postes)
mkdir -p /etc/veyon/keys/public/teacher
chmod 0755 /etc/veyon/keys/public
chmod 0755 /etc/veyon/keys/public/teacher
chown -R root:root /etc/veyon/keys/public

if [ -f "/etc/veyon/keys/public/teacher/key" ]; then
    chmod 0444 /etc/veyon/keys/public/teacher/key
    chown root:root /etc/veyon/keys/public/teacher/key
fi

# 2. Configuration de l'arborescence privée (postes enseignants uniquement)
if [ "$IS_TEACHER" = "true" ]; then
    mkdir -p /etc/veyon/keys/private/teacher
    chmod 0750 /etc/veyon/keys/private
    chmod 0750 /etc/veyon/keys/private/teacher
    chown -R root:enseignants /etc/veyon/keys/private
    if [ -f "/etc/veyon/keys/private/teacher/key" ]; then
        chmod 0440 /etc/veyon/keys/private/teacher/key
        chown root:enseignants /etc/veyon/keys/private/teacher/key
    fi
else
    # Sécurisation stricte sur poste élève : suppression de toute clef privée résiduelle
    rm -rf /etc/veyon/keys/private
fi

# Redémarrage du service Veyon si actif
if systemctl is-active --quiet veyon 2>/dev/null; then
    systemctl restart veyon || true
fi

echo "Configuration des clefs Veyon terminée avec succès."
