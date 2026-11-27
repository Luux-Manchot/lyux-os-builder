# Plan de Migration vers Bor — Étape 3 (Audit & Transfert)

Ce document recense l'audit des règles statiques actuelles dans `os-builder` et `lyux-desktop`, et définit leur destination cible dans **Bor** (`bor-server` + `bor-agent`) sans supprimer les rôles Ansible avant la validation en labo (Étape 5 de `MIGRATION_BOR.md`).

---

## 1. Inventaire et destination des règles existantes

| Source actuelle | Règles / Contenu | Destination | Justification |
| :--- | :--- | :--- | :--- |
| `os-builder/lyux-ansible/roles/lyux-kiosk/templates/kdeglobals.j2` | Restrictions actions KDE (`run_command=false`, `switch_user=false`, `unlockedDesktop=false`, verrouillage KCM apparence/users/systemd). | **Migrer vers Bor** (politique `KDE KConfig`) | Auto-réparation (*tamper protection*) si modifié localement ; différenciation facile `eleves` vs `enseignants`. |
| `os-builder/lyux-ansible/roles/lyux-kiosk/tasks/main.yml` | `plasma-welcome` désactivé (`Hidden=true`), `applications.menu` symlink, autostart `lyux-welcome.desktop`. | **Conserver dans l'image de base** | Socle commun de session KDE X11 à l'installation. |
| `os-builder/lyux-ansible/roles/lyux-profile-eleve/` | Suppression `/etc/veyon/keys/private`, déploiement clé publique Veyon, `Veyon.conf`, ouverture ports `11100`/`11200`. | **Conserver dans l'image / Ansible** | Supervision pédagogique Veyon (hors périmètre Bor selon `ADR-020`). |
| `os-builder/lyux-ansible/roles/lyux-profile-prof/` | Installation `veyon-master` + `veyon-plugins`, clé privée Veyon (`0440`, groupe `enseignants`), raccourcis profs. | **Conserver dans l'image / Ansible** (clé/service) ; **Visibilité appli via Bor / catalogue par rôle** | La clé privée Veyon et `Veyon.conf` restent gérés par le socle ; le lancement/masquage peut être renforcé par rôle. |
| `lyux-desktop/dolphin/10-udisks2-block-internal.rules` & `99-hide-internal-disks.rules` | Règles Polkit/udev interdisant le montage des disques internes (`udisks2`) aux non-`sudo` et masquant les disques système dans Dolphin. | **Migrer vers Bor** (politique `Polkit` + `Files`) | Permet d'autoriser/bloquer dynamiquement selon le groupe (`eleves` vs `admin`/`enseignants`) avec auto-réparation. |
| `os-builder/lyux-desktop-profile/` | Thème SDDM `lyux-sddm`, session **X11 obligatoire** (Wayland désactivé), écran de verrouillage, Kickoff, `/etc/skel` (fond d'écran). | **Conserver dans l'image de base** | Nécessaire dès le premier boot avant tout enrôlement Bor (et contrainte X11 pour Veyon/VMSVGA). |
| `os-builder/lyux-ansible/roles/lyux-profile-salles/defaults/main.yml` | Listes de paquets APT par discipline (`nsi`: `code`, `spyder`, `wireshark` ; `sciences`: `avogadro`, `stellarium`, `qgis`, `gimp` ; `techno`: `freecad`, `kicad`, `blender`). | **Migrer vers Bor** (politiques `Packages` APT/Flatpak par groupe de nœuds) | Déploiement et maintien à jour par salle/groupe sans rejouer Ansible manuellement. |
| Navigateurs (Firefox / Chromium) | Politiques de page d'accueil ENT, blocage extensions / paramètres proxy. | **Migrer vers Bor** (politiques natives `Firefox` / `Chrome`) | `bor-agent` écrit directement `/etc/firefox/policies/policies.json` et `/etc/chromium/policies/managed/bor_managed.json`. |

---

## 2. Groupes de politiques recommandés dans Bor (Parc universel)

> **Principe PC 100 % universel** : n'importe quel élève ou enseignant pouvant se connecter sur n'importe quel poste, **Bor** gère tout ce qui dépend de la **machine ou de la salle** (paquets installés sur disque, navigateurs, pare-feu, Polkit disques, KDE Kiosk commun), tandis que **LyuX** (`pam_session_hook.py` / `app_policy_sync.py`) applique à la volée au login ce qui dépend du **rôle de l'utilisateur** (visibilité des applis `eleve` vs `prof`, mono/multi-session, montage NAS `/homes`).

1. **`base-lyux`** *(tous les postes clients)*
   - Politiques navigateurs (page d'accueil ENT, proxy/certificats lycée).
   - Pare-feu de base (ports Veyon `11100-11400`, SSH admin).
   - Mises à jour de sécurité (`unattended-upgrades` via politique `Updates` de Bor).
2. **`eleves`** *(postes élèves)*
   - `KDE KConfig` strict (`unlockedDesktop=false`, KCM système bloqués, pas d'accès terminal si souhaité).
   - `Polkit` (`10-udisks2-block-internal.rules` pour interdire le montage des disques internes).
3. **`enseignants`** *(postes professeurs)*
   - `KDE KConfig` assoupli (personnalisation autorisée, outils de présentation).
   - Paquets `veyon-master` + raccourcis profs.
4. **`salle-nsi`** *(nœuds des salles NSI)*
   - Paquets APT : `git`, `gcc`, `g++`, `gdb`, `code`, `jupyter-notebook`, `spyder`, `wireshark`, `python3-numpy`, `python3-matplotlib`, etc.
5. **`salle-sciences`** *(nœuds Physique-Chimie / SVT)*
   - Paquets APT : `avogadro`, `stellarium`, `qgis`, `gimp`, `imagej`, `gnuplot`.
6. **`salle-techno`** *(nœuds STI2D / Technologie)*
   - Paquets APT : `freecad`, `kicad`, `blender`, `prusa-slicer`.

---

## 3. Règle de transition
- **Aucun rôle Ansible existant (`lyux-kiosk`, `lyux-profile-eleve`, `lyux-profile-prof`, `lyux-profile-salles`) n'est supprimé** tant que l'Étape 5 de validation en VM n'a pas confirmé l'application effective de chaque politique par `bor-agent`.
