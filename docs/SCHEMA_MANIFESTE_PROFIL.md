# Schéma de manifeste de profil LyuX & chaîne de confiance Ed25519 (Étape 3)

## 1. Schéma JSON (`lyux-profile-manifest`, v1)

```json
{
  "schema": "lyux-profile-manifest",
  "schema_version": 1,
  "profile_id": "nsi",
  "profile_version": "2026.11.1",
  "issued_at": "2026-11-25T12:00:00+00:00",
  "expires_at": "2026-12-25T12:00:00+00:00",
  "scope": {
    "building_id": "BAT-C",
    "room_id": "C14",
    "role": "eleve"
  },
  "artifacts": [
    {
      "id": "lyux-profile-nsi",
      "type": "config",
      "name": "lyux-nsi-config.json",
      "url": "https://github.com/Luux-Manchot/lyux-desktop/releases/download/v1.0.0/lyux-nsi-config.json",
      "sha256": "<64-hex-lowercase>",
      "size": 1024
    }
  ],
  "compatibility": {
    "debian": "13",
    "desktop": "plasma6-x11",
    "lyux_client_min": "1.0.0"
  },
  "signature": "<base64url-ed25519-detached-signature>"
}
```

## 2. Règles de validation
- `schema` doit valoir `lyux-profile-manifest` et `schema_version` doit valoir `1`.
- `profile_id` appartient exclusivement au catalogue stable (`standard`, `nsi`, `sciences`, `multimedia`, `atelier`, `prof`, `eleve`).
- `issued_at <= now` (tolérance 60 s) et `expires_at > now`.
- `scope` (`building_id`, `room_id`, `role`) doit correspondre à l'affectation du poste.
- Chaque artefact doit avoir un `type` autorisé (`deb`, `flatpak`, `theme`, `config`, `ansible`), une URL issue d'une source approuvée, une empreinte `sha256` (64 caractères hexadécimaux) et une taille strictement positive.
- La signature Ed25519 est calculée sur la représentation JSON canonique (`sort_keys=True`, sans le champ `signature`).

## 3. Gestion des clés Ed25519
- Les clés privées sont générées et stockées **hors dépôt Git** (`LYUX_KEYS_DIR`, par défaut côté serveur uniquement).
- Les postes ne reçoivent **jamais** de clé privée : seule la clé publique active (et la clé de secours lors d'une rotation) est exposée via `GET /api/v1/client/public-keys` ou embarquée dans l'ISO.
