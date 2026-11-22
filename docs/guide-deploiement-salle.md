# 🚀 Guide de Déploiement en Salle Pilote

Ce guide détaille la procédure étape par étape pour déployer le système **LyuX** sur une première salle pilote (ex: Salle Informatique B204) avant d'étendre la migration au reste du lycée.

---

## 📋 Checklist Avant Déploiement

- [ ] Inventaire des logiciels et périphériques (imprimantes, TNI/vidéoprojecteur) de la salle.
- [ ] Sauvegarde complète des postes existants (ou création d'une image disque de repli / rollback).
- [ ] Vérification de la prise en charge réseau (prise murale RJ45 fonctionnelle, bail DHCP attribué).
- [ ] Génération du code d'enrôlement OTP sur l'API serveur :
  ```bash
  curl -X POST http://api.lyux.lan:8000/api/v1/enroll/generate-otp \
    -H "Content-Type: application/json" \
    -d '{"admin_user": "lyux-admin", "room_id": "B204"}'
  ```

---

## 🛠️ Déroulement de l'Installation

### 1. Poste Enseignant (`B14-PROF`)
1. Insérer la clé USB d'installation LyuX.
2. Démarrer le PC sur la clé USB (touche `F12` ou `F11` au démarrage).
3. L'assistant `lyux-enrollment` se lance automatiquement :
   * Indiquer l'adresse du serveur : `http://192.168.100.10:8000`
   * Saisir le code OTP d'enrôlement.
   * Sélectionner la salle : `B14`.
   * Cocher **"Poste Enseignant"** (installe Veyon Master).
4. Le poste applique le profil Ansible et redémarre.

### 2. Postes Élèves (`B14-01` à `B14-30`)
1. Insérer la clé USB (ou démarrer en réseau PXE).
2. Saisir le même code OTP (valable pour toute la salle).
3. Laisser la numérotation automatique attribuer les noms `b14-01`, `b14-02`, etc.
4. Le profil `nsi` et le verrouillage Kiosk s'appliquent automatiquement.

---

## 🧪 Tests de Validation Post-Déploiement

1. **Test d'authentification** :
   * Se connecter avec un compte élève (`eleve.dupont`) : vérifier l'ouverture de `lyux-welcome` et la présence de `~/Espace_Personnel`.
   * Se connecter avec un compte prof (`prof.durand`) : vérifier l'accès à **Veyon Master** et aux partages enseignants.
2. **Test de supervision Veyon** :
   * Depuis le poste prof, vérifier que tous les écrans des élèves sont visibles en temps réel.
   * Tester le verrouillage général des écrans.
3. **Test d'impression & TNI** :
   * Lancer une impression de test vers l'imprimante réseau de la salle.
   * Tester l'interactivité du vidéoprojecteur / écran tactile.
4. **Test du widget de ticket** :
   * Ouvrir `lyux-report` sur un poste élève, envoyer un rapport de test et vérifier sa création instantanée dans **GLPI**.
