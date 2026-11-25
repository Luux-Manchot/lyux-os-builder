# 💿 LyuX OS Builder (`lyux-os-builder`)

Outillage d'automatisation, playbooks Ansible et générateur d'image ISO Debian 13 unattended pour le déploiement massif de postes clients **LyuX**.

## 📦 Outils inclus
- **`lyux-iso-builder`** : Scripts de génération d'ISO bootable avec Calamares et configuration préinstallée.
- **`lyux-ansible`** : Rôles et playbooks de configuration automatisée des postes (`lyux-base`, `lyux-kiosk`, `lyux-profile-eleve`, `lyux-profile-prof`, `lyux-profile-salles`, Veyon).
- **`lyux-lab-vm`** : Environnement de test local sous VirtualBox et Vagrant.

## Architecture cible du client

Le [plan de migration vers le client universel](docs/PLAN_CLIENT_UNIVERSEL_PROFILS_SERVEUR.md) décrit les étapes proposées pour une ISO Debian générique, l'évaluation de Calamares et le provisionnement sécurisé des profils visuels et logiciels depuis le serveur. Le [guide de build actuel](docs/GUIDE_NOUVELLE_METHODE_BUILD_ISO_ET_THEMES.md) reste une description du pipeline Preseed existant, pas de cette cible.
