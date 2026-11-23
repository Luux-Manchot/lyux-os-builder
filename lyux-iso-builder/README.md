# 💿 LyuX ISO Builder
> **Générateur d'images ISO légères d'installation pour clé USB & Démarrage Réseau PXE.**

Ce sous-projet contient les recettes et scripts pour compiler les images ISO **LyuX**. Le socle de référence est **Debian 13 Trixie** (version vérifiée dans les VM `LyuX-Server` et `LyuX-C14-PC02`). L'ISO source utilisée est `debian-13.8.0-amd64-netinst.iso`.

---

## 🎯 Philosophie de l'Image ISO LyuX (Annexe A)

Contrairement aux images disques traditionnelles de plusieurs gigaoctets qui deviennent obsolètes dès qu'un logiciel change :
1. **L'ISO LyuX est ultra-légère** (~600 Mo) : elle contient uniquement le noyau Linux, l'environnement KDE minimal, le réseau et l'assistant `enrollment`.
2. **Une seule ISO pour tout le lycée** : que ce soit pour une salle NSI, un labo de SVT ou un bureau de Vie Scolaire, c'est le **serveur central qui décide** de ce que devient le poste via Ansible.
3. **Mise à jour sans refaire la clé** : pour changer la suite logicielle d'une salle, on modifie le profil Ansible sur le serveur, jamais l'ISO.

---

## 🛠️ Comment Générer l'ISO

### Sur une machine Linux / Debian (ou dans une VM de build) :
```bash
cd os-builder/lyux-iso-builder
sudo apt install -y live-build xorriso isolinux
sudo ./build-iso.sh        # ISO installateur client
sudo ./build-client-iso.sh # ISO client (Debian + KDE + apps)
sudo ./build-server-iso.sh # ISO appliance serveur
```
Les scripts calculent la racine du workspace via `REPO_ROOT` : ils peuvent être lancés depuis n'importe quel dossier. Sorties :
- client → `lyux-desktop/build/` (`lyux-installer-latest.iso`, `lyux-client-installer-latest.iso`, `lyux-client-autonomous-installer.iso`, `latest.json`, `latest.yml`, `RELEASE_v1.0.0.md`)
- serveur → `lyux-server/build/` (`lyux-server-appliance-latest.iso`)

Ces dossiers `build/` sont ignorés par Git.

---

## 📂 Structure du Répertoire

```
lyux-iso-builder/
├── build-iso.sh                # Script de compilation automatisé
├── preseed/
│   └── preseed.cfg             # Fichier de réponses pour installation automatique sans question
├── config/
│   ├── package-lists/          # Paquets de base (KDE minimal, SSSD, Python, Veyon)
│   └── hooks/                  # Scripts post-installation (injection de `enrollment`)
└── README.md
```
