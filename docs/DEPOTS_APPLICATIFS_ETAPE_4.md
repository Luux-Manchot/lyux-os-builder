# Dépôts applicatifs signés et application de profils (Étape 4)

## 1. Architecture retenue
- **Dépôt APT pilote signé (Option A)** : `lyux-server/lyux-server-api/src/apt_repo.py` construit des paquets `.deb` LyuX (ex. `lyux-profile-standard_1.0.0_all.deb`) et génère `Packages`, `Packages.gz`, `Release` et `Release.ed25519` sous `/api/v1/apt-repo/...`.
- **Autorité de signature** : les manifestes de profils et `Release` sont signés en **Ed25519** (`profile_trust.py`) ; `apt-cacher-ng` reste uniquement un cache optionnel et n'est jamais considéré comme dépôt signé.
- **Catalogue strict** : seuls les paquets Debian (`APPROVED_DEBIAN_PACKAGES`) et Flatpak (`APPROVED_FLATPAKS`) listés au catalogue sont acceptés ; aucun champ `command`, `script` ou URL hors sources approuvées n'est toléré.

## 2. Application côté client
- `profile_applier.py` récupère le manifeste signé via `GET /api/v1/client/profile-manifest`, vérifie la signature Ed25519, télécharge en répertoire temporaire sécurisé, contrôle taille + SHA-256, installe les `.deb` approuvés (`dpkg -i`), applique la configuration KDE/X11 (`DisplayServer=x11`, sans activer Wayland), puis rapporte l'état et les versions installées à `POST /api/v1/client/profile-report`.
- En cas d'échec de téléchargement ou d'installation, `rollback_profile()` restaure automatiquement le dernier profil valide et signale `rolling_back` au serveur.
