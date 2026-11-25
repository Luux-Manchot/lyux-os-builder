# Guide — Choix des clés de maintenance administrateur (LyuX)

Ce document précise les types de clés matérielles recommandés pour le déverrouillage administrateur / maintenance locale (changement d'IP serveur, ré-enrôlement, console root de secours), en lien avec l'issue `Luux-Manchot/lyux-os-builder#17`.

## Comparatif des options

| Option | Matériel requis | Sécurité (anti-clonage) | Usage recommandé |
| --- | --- | --- | --- |
| **1. Clé FIDO2 / U2F** *(Recommandé)* | 2× YubiKey (ex. Security Key NFC / YubiKey 5), Nitrokey FIDO2 ou SoloKey | **Très élevée** : la clé privée ne quitte jamais la puce (impossible à copier) | Établissements souhaitant un déverrouillage physique infalsifiable (`pam_u2f` / `libfido2`) |
| **2. Clé USB standard signée** *(Économique)* | 2× clés USB classiques (ex. 8–16 Go) | **Moyenne** : le fichier signé peut être copié si la clé est lue par un tiers | Maintenance ponctuelle uniquement (débrancher dès l'opération terminée) ou combinée à un PIN |
| **3. Mot de passe admin local** *(Sans matériel)* | Aucun | Dépend de la robustesse du mot de passe | Établissements ne souhaitant pas gérer de clés physiques |

## Recommandation pour 2 clés physiques

1. **Si le budget le permet (~25–55 € / clé)** : prendre **2 clés FIDO2** (1 principale pour le technicien + 1 clé de secours conservée en lieu sûr).
   - Sous Debian 13, `libfido2` / `pam-u2f` permettent un défi cryptographique au boot ou dans le mode maintenance : la machine envoie un challenge aléatoire que seule la puce matérielle peut signer.
2. **Sans achat de clé FIDO2** : utiliser **2 clés USB classiques** formatées en `ext4` ou `vfat` avec un fichier de jeton signé par la clé privée de l'établissement (vérifié par la clé publique du poste) et, en complément, l'identifiant matériel USB (`udev` `ID_SERIAL_SHORT`).
   - Ne jamais utiliser un simple fichier texte ou un label de partition seul (trivialement falsifiable).
   - Ne jamais laisser la clé USB de maintenance branchée en permanence sur un poste élève.
