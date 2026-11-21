#!/usr/bin/env bash
# Script de provisionnement automatique du Serveur LyuX sous Vagrant / Debian 12
set -euo pipefail

echo "======================================================"
echo "🚀 Déploiement automatique du Serveur Central LyuX..."
echo "======================================================"

export DEBIAN_FRONTEND=noninteractive

# 1. Dépendances de base & Docker
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    samba \
    samba-common-bin \
    acl \
    python3 \
    python3-pip \
    git

# Installation Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 2. Configuration Samba & Partages
mkdir -p /srv/samba/{homes,classes,profs,administration,commun}
chmod 777 /srv/samba/{homes,classes,profs,administration,commun}

# 3. Création des utilisateurs de démo
groupadd -g 2000 eleves || true
groupadd -g 2001 enseignants || true
groupadd -g 2003 viesco || true

useradd -m -g enseignants -s /bin/bash prof.durand || true
echo "prof.durand:Prof2026!" | chpasswd
(echo "Prof2026!"; echo "Prof2026!") | smbpasswd -a -s prof.durand

useradd -m -g eleves -s /bin/bash eleve.dupont || true
echo "eleve.dupont:Eleve2026!" | chpasswd
(echo "Eleve2026!"; echo "Eleve2026!") | smbpasswd -a -s eleve.dupont

useradd -m -g viesco -s /bin/bash admin.scolaire || true
echo "admin.scolaire:Admin2026!" | chpasswd
(echo "Admin2026!"; echo "Admin2026!") | smbpasswd -a -s admin.scolaire

# 4. Lancement de la stack Docker LyuX
if [ -d "/vagrant/projects/lyux-server-infra" ]; then
    cd /vagrant/projects/lyux-server-infra
    cp -n .env.example .env || true
    docker compose up -d || true
fi

echo "✅ Serveur LyuX déployé et opérationnel !"
