# ⚙️ LyuX Ansible
> **Gestion de configuration centralisée & Profils de salles automatisés (Ansible / Ansible-Pull).**

Ce sous-projet contient toute l'infrastructure sous forme de code (**Infrastructure as Code**) pour configurer, sécuriser et maintenir automatiquement les centaines de postes clients Linux (KDE Plasma) du lycée.

---

## 🎯 Fonctionnalités

1. **Rôle `lyux-base`** :
   * Configuration du proxy APT local (`Apt-Cacher-NG`).
   * Intégration à l'annuaire via **SSSD** (LDAP / Samba-AD).
   * Configuration de **`pam_mount`** : montage automatique du répertoire personnel `/home/<user>` et des partages de classe au login.
   * Installation du socle commun de logiciels (LibreOffice, Firefox, VLC, Python/Thonny, GeoGebra).
2. **Rôle `lyux-kiosk`** :
   * Personnalisation du bureau KDE Plasma (apparence moderne et intuitive).
   * Verrouillage KDE Kiosk (impossibilité de modifier la barre des tâches ou dérégler les lanceurs).
3. **Rôles par profil d'utilisateur** :
   * `lyux-profile-prof` : Déploiement de **Veyon Master** (supervision), accès aux dossiers de dépôt, raccourci de réinitialisation de mot de passe.
   * `lyux-profile-eleve` : Déploiement de **Veyon Service** (écouteur client), restrictions système.
   * `lyux-profile-viesco` : Outils de gestion, raccourcis GLPI et LAM.
4. **Rôles par profil de salle (Disciplines)** :
   * **NSI & Maths** : VS Code, Git, C/C++, Thonny, Jupyter, Cisco Packet Tracer, Scilab, Octave.
   * **Physique-Chimie & SVT** : Avogadro, Tracker, Stellarium, ImageJ, QGIS.
   * **Sciences de l'Ingénieur / Techno** : FreeCAD, KiCad, Blender, Cura / PrusaSlicer.
 5. **Rôle `lyux-apps`** :
   * Déploiement des applications depuis `../../lyux-desktop/applications` vers `/opt/lyux/apps`.
   * `welcome` (assistant de bienvenue) déployé et lancé au démarrage par défaut.
   * `station`, `report` et `enrollment` désactivés par défaut (à activer dans `defaults/main.yml`).
   * Dépendances Python installées via les paquets Debian (`python3-pyqt6`, `python3-requests`, `python3-psutil`, `python3-rich`).

---

## 📂 Structure du Répertoire

```
lyux-ansible/
├── ansible.cfg                 # Configuration d'exécution Ansible
├── inventory/
│   ├── hosts.yml               # Définition des groupes et des machines
│   └── group_vars/             # Variables spécifiques par groupe de salles
├── playbooks/
│   ├── site.yml                # Déploiement complet de l'établissement
│   ├── enroll.yml              # Playbook exécuté lors de l'enrôlement d'un poste
│   └── nightly-update.yml      # Tâche planifiée de nuit (mises à jour & nettoyage)
└── roles/
    ├── lyux-base/              # SSSD, PAM Mount, Socle commun
    ├── lyux-kiosk/             # Verrouillage et thème KDE Plasma
    ├── lyux-profile-prof/      # Veyon Master & Outils prof
    ├── lyux-profile-eleve/     # Veyon Service & Restrictions élève
    ├── lyux-profile-salles/    # Logiciels spécifiques par discipline
    └── lyux-apps/              # Applications clients depuis lyux-desktop/applications
```

---

## 🚀 Utilisation

### Mode Push (Depuis le serveur central) :
Appliquer la configuration sur tout le parc ou une salle :
```bash
# Déployer sur toutes les machines de la salle NSI B204
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit salle_b204

# Déployer uniquement le socle commun
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags base
```

### Mode Pull (Exécuté en local par la machine ou la clé USB) :
```bash
ansible-pull -U https://git.lyux.lan/lyux/lyux-ansible.git -i localhost, playbooks/enroll.yml --extra-vars "lyux_room=salle_b204"
```
