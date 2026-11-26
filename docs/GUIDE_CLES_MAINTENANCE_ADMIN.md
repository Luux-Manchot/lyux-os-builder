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

---

## Procédure de dépannage local (`root`) — Serveur déconnecté ou changement d'IP

*(En attendant l'activation des clés de sécurité matérielles, le poste conserve uniquement le compte local `root` protégé par le mot de passe défini lors de l'OOBE.)*

### 1. Ouvrir une console locale `root`
Sur l'écran de connexion (SDDM) ou depuis une session figée :
- Appuyer sur **`Ctrl + Alt + F2`** (ou `F3`) pour passer en console texte (TTY).
- Saisir l'identifiant **`root`** et le **mot de passe `root`** configuré à l'installation.

### 2. Vérifier le réseau et tester la nouvelle IP du serveur
```bash
ip -br addr
curl -s http://<NOUVELLE_IP_SERVEUR>:8000/health
```
Si le câble ou le DHCP ne répond pas, vérifier l'interface (`dhclient enp0s3` ou configuration IP statique temporaire).

### 3. Changer l'IP du serveur et relancer l'enrôlement (OOBE)
```bash
python3 - << 'EOF'
import json
from pathlib import Path

state_file = Path("/var/lib/lyux/enrollment-state.json")
data = json.loads(state_file.read_text(encoding="utf-8")) if state_file.exists() else {}
data["server_url"] = "http://<NOUVELLE_IP_SERVEUR>:8000"
data["state"] = "pending"
state_file.parent.mkdir(parents=True, exist_ok=True)
state_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
EOF

# Déclencher le ré-enrôlement / OOBE
echo "reenroll" > /var/lib/lyux/first-boot-pending
systemctl restart lyux-enrollment.service
```

### 4. Restaurer le profil de secours en cas d'échec de mise à jour
```bash
PYTHONPATH=/opt/lyux/apps/enrollment/src python3 -c "from profile_manifest import rollback_profile; print(rollback_profile())"
cat /var/log/lyux-maintenance.log
```

### 5. Revenir à l'interface graphique
- Appuyer sur **`Ctrl + Alt + F1`** (ou exécuter `systemctl restart sddm`).

