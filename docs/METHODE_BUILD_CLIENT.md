# Méthode de build client LyuX — la façon propre

> Ce document remplace le dossier `client/` supprimé. Les anciens scripts restent récupérables dans l'historique Git (`git log --all -- client/`). Il décrit comment intégrer leurs fonctions dans la chaîne de build ISO sans bricolage manuel.

## 1. Principe directeur

**Une seule source de vérité : les fichiers versionnés de `os-builder/`.** La VM sert à *valider* l'image, jamais à la *définir*. Toute modification faite à la main sur la VM master finit par dériver de ce qui est dans Git : c'est le bug garanti.

L'architecture visée tient en 4 couches :

| Couche | Emplacement | Contenu |
| :--- | :--- | :--- |
| 1. Base système | `lyux-master.squashfs` (capture Debian 12 + KDE) | Noyau, KDE Plasma, SSSD, réseau, outils de base |
| 2. Surcouche système | `os-builder/lyux-ansible/roles/` | Comptes, SSSD, pam_mount, NFS, proxy apt, kiosk, services poste |
| 3. Profil graphique | `os-builder/lyux-desktop-profile/` | KDE, SDDM, skel, lockscreen, kickoff |
| 4. Overlay ISO | `os-builder/lyux-iso-builder/create-overlay-iso.sh` | **Uniquement l'installateur** (`zz-installer.squashfs`) |

`lyux-installer.sh` partitionne le disque, extrait le squashfs, pose hostname/réseau/fstab puis prévient l'API (`POST /api/v1/parc/enroll`). Il ne doit **pas** installer de logique métier : celle-ci est déjà dans l'image.

## 2. Où sont passés les scripts de `client/`

Ancien chemin → nouveau chemin recommandé :

| Ancien fichier `client/lyux-client-scripts/` | Destination | Note |
| :--- | :--- | :--- |
| `lyux-app-sync.py` | `roles/lyux-client-runtime/files/lyux-app-sync` | Agent de synchro du catalogue (`/api/v1/apps/client`, timeout 10 s) |
| `lyux-app-sync.service` / `.timer` | `roles/lyux-client-runtime/templates/` | `OnBootSec=15s`, `OnUnitActiveSec=60s` |
| `lyux-storage-manager.py` | `roles/lyux-client-runtime/files/lyux-storage-manager` | Ménage disque (seuil 80 % / 4 Go) + stats utilisateurs |
| `lyux-storage-manager.service` / `.timer` | `roles/lyux-client-runtime/templates/` | `OnBootSec=30s`, `OnUnitActiveSec=5min` |
| `install-app-sync.sh`, `install-storage-manager.sh` | **Supprimés** | Remplacés par les tâches Ansible `copy` + `systemd` ci-dessous |
| `pam_mount.conf.xml` | `roles/lyux-base/templates/pam_mount.conf.xml.j2` | Déjà présent — vérifier juste les options `nosuid,nodev` |
| `setup-nfs-fstab.sh` | `roles/lyux-base/tasks/main.yml` | Montage `/srv/samba/homes` via template fstab, pas de `>> /etc/fstab` |
| `setup-proxy.sh` | `roles/lyux-base/templates/01apt-cacher-proxy.j2` | Déjà présent (`http://192.168.10.1:3142`) |
| `lockdown-kde-discover.sh` | `roles/lyux-kiosk/` | Bloquer Discover/AppStream dans le profil élève |
| `patch-plasma-defaults.py` | `lyux-desktop-profile/` + `roles/lyux-kiosk/` | Retirer Discover des plasmoïdes KDE via templates |

Les 7 fichiers `client/test-*.sh`, `client/test-pam.py`, `client/verify-password.sh` et `client/test-serveur.txt` étaient des scripts de debug avec identifiants en dur. Ils sont supprimés : la validation se fait dans `tests/` (pytest), pas avec des scripts ad hoc.

## 3. Exemple de rôle Ansible à créer

```
os-builder/lyux-ansible/roles/lyux-client-runtime/
├── defaults/main.yml
├── files/
│   ├── lyux-app-sync
│   └── lyux-storage-manager
├── templates/
│   ├── lyux-app-sync.service.j2
│   ├── lyux-app-sync.timer.j2
│   ├── lyux-storage-manager.service.j2
│   └── lyux-storage-manager.timer.j2
└── tasks/main.yml
```

`defaults/main.yml` :

```yaml
lyux_server_ip: "192.168.10.1"
lyux_api_url: "http://{{ lyux_server_ip }}:8000"
```

`tasks/main.yml` (extrait) :

```yaml
- name: Installer les agents LyuX
  ansible.builtin.copy:
    src: "{{ item }}"
    dest: "/usr/local/bin/{{ item }}"
    mode: "0755"
  loop:
    - lyux-app-sync
    - lyux-storage-manager

- name: Installer les units systemd
  ansible.builtin.template:
    src: "{{ item }}.j2"
    dest: "/etc/systemd/system/{{ item }}"
    mode: "0644"
  loop:
    - lyux-app-sync.service
    - lyux-app-sync.timer
    - lyux-storage-manager.service
    - lyux-storage-manager.timer
  notify: recharger systemd

- name: Activer les timers
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop:
    - lyux-app-sync.timer
    - lyux-storage-manager.timer
```

`handlers/main.yml` :

```yaml
- name: recharger systemd
  ansible.builtin.systemd:
    daemon_reload: true
```

Les URLs en dur (`192.168.10.1:8000`) des anciens scripts deviennent des variables Ansible : une seule modification pour tout le parc.

## 4. Procédure de build

```bash
# 1. Provisionner la VM master UNIQUEMENT via Ansible
cd os-builder/lyux-ansible
ansible-playbook -i inventory/hosts playbooks/site.yml

# 2. Vérifier le profil graphique
cd ../lyux-desktop-profile
sudo ./apply-all.sh

# 3. Capturer l'image master (VM propre, sans modif manuelle)
cd ../lyux-iso-builder
sudo ./capture-master.sh

# 4. Construire l'ISO puis ajouter l'overlay installateur
sudo ./build-autonomous-iso.sh
sudo ./create-overlay-iso.sh

# 5. Tester dans la VM de lab avant distribution
cd ../lyux-lab-vm
vagrant up
```

Ordre important : **`create-overlay-iso.sh` après `build-autonomous-iso.sh`**, sinon `zz-installer.squashfs` n'est pas dans l'ISO. Le nom `zz-…` garantit qu'il est monté en *top layer* au-dessus de `filesystem.squashfs` par live-boot.

## 5. Règles d'or

1. **Jamais de `apt install` ou `cp` à la main sur la VM master.** Si ça marche sur la VM mais pas après capture, c'est que ce n'est pas dans Ansible.
2. **Aucun secret en dur.** `capture-master.sh` contient encore `PASSWORD="LyuxAdmin2026!"` : le remplacer par une variable d'environnement ou Ansible Vault. Même chose pour les anciens `test-login.sh` supprimés.
3. **Nettoyage machine spécifique** avant capture : `machine-id`, clés SSH (`ssh_host_*`), leases DHCP, logs — déjà fait dans `capture-master.sh`, à vérifier à chaque évolution.
4. **Tout paramètre dans une variable** : IP du serveur, ports API, seuils disque, noms d'unités. Pas de valeur codée en dur dans un script.
5. **Traçabilité** : la version est écrite dans `/etc/lyux-release` par l'installateur. La garder alignée avec le tag Git du build.
6. **Validation automatisée** : `pytest tests/` avant de publier une ISO. Les tests E2E lisent les vrais fichiers du dépôt, pas des copies.

## 6. Résumé de ce qui change

- Plus de dossier `client/` à la racine : les agents sont dans `os-builder/lyux-ansible`, les réglages KDE dans `lyux-desktop-profile`.
- L'ISO ne contient que la base + l'installateur ; la surcouche métier est déployée au build via Ansible.
- Une ISO est reproductible : elle peut être reconstruite à partir du dépôt seul, sans dépendre de l'état d'une VM.
