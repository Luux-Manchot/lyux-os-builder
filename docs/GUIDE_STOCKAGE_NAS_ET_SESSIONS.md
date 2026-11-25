# Guide — Stockage NAS multi-années, synchronisation différentielle et contrôle des sessions

Ce document décrit l'architecture cible pour la gestion des utilisateurs (`prenom.nom` via Samba-AD), le stockage NAS sur plusieurs années scolaires (2024–2027+, redoublements inclus), la synchronisation différentielle entre postes et la politique de sessions simultanées par rôle.

---

## 1. Structure du stockage NAS (`/srv/samba/`)

**Règle d'or** : les dossiers personnels des utilisateurs ne sont **jamais** rangés par classe ni par année de promotion. Un élève qui redouble ou change de filière conserve son espace personnel intact sans aucun déplacement de données.

```text
/srv/samba/
├── homes/
│   └── <uid_immuable>/          # Dossier personnel permanent (toute la scolarité)
│       ├── Documents/
│       ├── Bureau/
│       └── Projets/
├── classes/
│   └── <annee_scolaire>/        # Ex: 2026-2027
│       └── <classe>/            # Ex: 1G1, T-NSI
│           ├── Cours/           # Profs R/W, Élèves R
│           └── Devoirs/         # Boîte de dépôt étanche
├── commun/                      # Ressources partagées établissement
└── archives/
    └── <annee_depart>/          # Comptes archivés (lecture seule avant purge RGPD)
        └── <uid_immuable>/
```

### Gestion des transitions annuelles (redoublement, changement de classe, départ)
- **Passage en classe supérieure ou redoublement** : le compte Samba-AD reste `active`, `/srv/samba/homes/<uid>/` ne change pas ; seul le groupe de classe (`memberOf`) est mis à jour (`2NDE1` → `1G1`, ou maintien en `2NDE1` en cas de redoublement).
- **Départ / fin de scolarité** : passage en statut `archived` avec transfert en lecture seule vers `/srv/samba/archives/<annee>/<uid>/` pour une période de grâce (ex. 6 mois) avant suppression conforme RGPD.

---

## 2. Synchronisation différentielle à la connexion / déconnexion

1. **Vérification serveur (`POST /api/v1/sessions/login-check`)** :
   - Le poste client vérifie que l'utilisateur existe, contrôle la politique de session du rôle et récupère le chemin NAS (`/srv/samba/homes/<uid>`) ainsi que `last_machine` et `last_sync_at`.
2. **Récupération au login (delta uniquement)** :
   - Si l'utilisateur s'est connecté sur un autre poste la dernière fois (`last_machine != hostname`) ou n'a pas encore les derniers fichiers en local, seuls les fichiers **absents ou plus récents** sur le NAS sont rapatriés (`rsync -av --update`).
   - Les dossiers communs (`Cours`, `Devoirs`) restent montés directement en SMB3 via `pam_mount` sans copie locale.
3. **Envoi au logout (`POST /api/v1/sessions/logout`)** :
   - Seuls les fichiers créés ou modifiés localement sont poussés vers le NAS, et le serveur met à jour `last_machine` et `last_sync_at`.

---

## 3. Contrôle des sessions simultanées selon le rôle

La permission RBAC **`sessions.multi`** (configurable dans *Rôles & Permissions*) détermine si un compte peut ouvrir plusieurs sessions simultanées sur des postes différents :

| Rôle | `sessions.multi` par défaut | Comportement si déjà connecté ailleurs |
| --- | --- | --- |
| **Élève** (`eleve`) | `false` | Connexion refusée (`409`) avec message : *« Utilisateur déjà connecté sur le poste `<hostname>` »* |
| **Professeur** (`enseignant`) | `true` | Connexion autorisée sur plusieurs postes |
| **Vie scolaire** (`viesco`) | `false` | Configurable dans la matrice RBAC |
| **Direction** (`direction`) | `true` | Connexion autorisée |
| **Technicien** (`technicien`) | `true` | Connexion autorisée |
| **Administrateur** (`admin`) | `true` | Connexion autorisée |

---

## 4. Issue de suivi associée

- **Titre proposé** : `[Sessions & NAS] Contrôle de session unique/multi-session par rôle, sync différentielle home NAS et stockage multi-années (2024–2027)`
- **Critères de validation** :
  1. Un élève déjà connecté sur `PC-A` reçoit un refus explicite sur `PC-B` (*« Utilisateur déjà connecté sur le poste PC-A »*).
  2. Un professeur/technicien/admin peut se connecter sur plusieurs postes si `sessions.multi` est actif.
  3. À la connexion sur un nouveau poste, seuls les fichiers absents ou modifiés depuis la dernière session sont synchronisés depuis `/srv/samba/homes/<uid>`.
  4. Le changement de classe ou le redoublement ne modifie jamais le chemin `/srv/samba/homes/<uid>`.
