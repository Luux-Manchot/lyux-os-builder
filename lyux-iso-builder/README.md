# 💿 LyuX ISO Builder
> **Générateur d'images ISO légères d'installation pour clé USB & Démarrage Réseau PXE.**

Ce sous-projet contient les recettes et scripts pour compiler l'image ISO minimale **LyuX** (basée sur Debian 12 Bookworm).

---

## 🎯 Philosophie de l'Image ISO LyuX (Annexe A)

Contrairement aux images disques traditionnelles de plusieurs gigaoctets qui deviennent obsolètes dès qu'un logiciel change :
1. **L'ISO LyuX est ultra-légère** (~600 Mo) : elle contient uniquement le noyau Linux, l'environnement KDE minimal, le réseau et l'assistant `lyux-enrollment`.
2. **Une seule ISO pour tout le lycée** : que ce soit pour une salle NSI, un labo de SVT ou un bureau de Vie Scolaire, c'est le **serveur central qui décide** de ce que devient le poste via Ansible.
3. **Mise à jour sans refaire la clé** : pour changer la suite logicielle d'une salle, on modifie le profil Ansible sur le serveur, jamais l'ISO.

---

## 🛠️ Comment Générer l'ISO

### Sur une machine Linux / Debian (ou dans une VM de build) :
```bash
cd projects/lyux-iso-builder
sudo apt install -y live-build xorriso isolinux
sudo ./build-iso.sh
```
Le fichier généré sera : `lyux-desktop/build/lyux-installer-latest.iso`.

---

## 📂 Structure du Répertoire

```
lyux-iso-builder/
├── build-iso.sh                # Script de compilation automatisé
├── preseed/
│   └── preseed.cfg             # Fichier de réponses pour installation automatique sans question
├── config/
│   ├── package-lists/          # Paquets de base (KDE minimal, SSSD, Python, Veyon)
│   └── hooks/                  # Scripts post-installation (injection de lyux-enrollment)
└── README.md
```
