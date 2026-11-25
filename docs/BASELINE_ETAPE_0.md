# Baseline et décisions — Étape 0

**Date :** 24 novembre 2026

**Statut :** en cours; aucune décision d'architecture n'est considérée comme validée sans preuve VM

**Périmètre :** OS Builder uniquement

## 1. État conservé

Le workspace contient les modifications locales suivantes dans `os-builder` :

- `README.md`
- `docs/GUIDE_NOUVELLE_METHODE_BUILD_ISO_ET_THEMES.md`
- `lyux-iso-builder/build-client-iso.sh`
- `lyux-iso-builder/preseed/preseed.cfg`
- `lyux-iso-builder/verify-client-iso.sh`
- `tests/e2e/test_client_iso_visual.py`
- `tests/e2e/test_tier3_interactions.py`
- `docs/PLAN_CLIENT_UNIVERSEL_PROFILS_SERVEUR.md` est nouveau et non suivi

Ces changements sont conservés tels quels. Ils ne sont ni écrasés ni réinitialisés pendant l'étape 0.

## Images de référence disponibles

- `lyux-client-installer-latest.iso` (référence Étape 1 validée, 24 novembre 2026 20:18:14)
  - taille: 1 052 583 936 octets (1003 Mo);
  - SHA-256: `98E620980FBE70CC43A0A616A771FFE29197A715D42B634B06D461CA3EDC549E`.
- `lyux-client-autonomous-installer.iso`
  - taille: 3 646 717 952 octets;
  - SHA-256: `9CFD04335AC928373C6A9B3F393C92C49446E8197DE150E3A57FA6893EBD40FF`.

VirtualBox 7 est disponible à `C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`. La VM `LyuX-Client-Test` est déjà configurée en Debian 64-bit, BIOS, démarrage DVD puis disque, avec 4 Go de RAM et une carte réseau interne.

## Résultat du premier boot neuf

Une VM neuve `LyuX-Step0-Boot` a été créée avec 4 Go de RAM, 32 Go de disque VDI vierge, firmware BIOS et l'ISO `lyux-client-installer-latest.iso` attachée en DVD. Observations enregistrées:

- l'ISO affiche l'écran de chargement Debian 13;
- l'installateur passe par la détection réseau puis démarre automatiquement le partitionnement;
- aucun écran de configuration DHCP ou de choix de miroir n'est apparu pendant cette séquence;
- l'installation atteint « Installer le système de base » et poursuit depuis les composants du média.

Captures: `VM/LyuX-Step0-Boot/step0-screen-2.png` à `step0-screen-6.png`.

Cette preuve démontre le démarrage de l'installateur, pas encore une installation complète jusqu'au reboot, ni l'OOBE. Elle ne ferme pas l'issue #16.

## 2. Chemin d'installation actuel

Le chemin de référence actif reste Debian Preseed :

- source Debian : Debian 13.8 Netinst;
- automatisation : `lyux-iso-builder/preseed/preseed.cfg`;
- bureau : `tasksel tasksel/first multiselect standard, kde-desktop`;
- gestionnaire graphique : SDDM, affichage X11;
- personnalisations graphiques : intégrées dans l'ISO;
- réseau Debian : désactivé pendant l'installation;
- premier démarrage : service `lyux-enrollment.service` activé;
- personnalisation : profil graphique appliqué depuis le payload embarqué.

Calamares existe dans le dépôt comme configuration candidate, mais aucune chaîne Calamares complète n'est démontrée dans les scripts actifs de build. Preseed reste donc le chemin de référence jusqu'au prototype.

## 3. Inventaire des composants présents

### Socle d'installation

- noyau Debian 13 et pilotes du Netinst;
- `standard` depuis tasksel;
- `kde-desktop`;
- GRUB;
- locale française, clavier AZERTY;
- compte local temporaire `lyux-admin`;
- mot de passe injecté au build, jamais enregistré comme valeur fixe dans le dépôt.

### Paquets explicitement demandés par le Preseed

- `sssd`
- `cifs-utils`
- `libpam-mount`
- `python3-pyqt6`
- `python3-requests`
- `python3-psutil`
- `python3-rich`
- `python3-pip`
- `isc-dhcp-client`
- `git`
- `curl`
- `ansible`

Cette liste décrit les paquets demandés par la recette actuelle. Elle ne constitue pas encore la liste minimale prouvée du boot/OOBE: une mesure après installation sur VM est requise avec `dpkg-query` et une analyse des dépendances réellement utilisées.

### OOBE, bureau et personnalisation

- applications `enrollment` et `welcome` depuis le payload;
- profil SDDM/KDE depuis `lyux-desktop-profile`;
- thèmes Orchis KDE, WhiteSur KDE et Tela-circle;
- restrictions Kiosk;
- Plymouth Breeze;
- verrouillage KDE;
- désactivation de la session Wayland;
- service d'enrôlement au premier démarrage.

## 4. Décision retenue — Plasma dans l'ISO

**Choix retenu pour la cible:** inclure le socle Plasma minimal dans l'ISO.

Justification: la référence doit pouvoir atteindre un OOBE graphique sans dépendre du réseau et éviter une variante qui échange un problème d'installation contre un nouveau blocage au premier démarrage.

Le socle embarque KDE Plasma avec SDDM en X11, les dépendances graphiques nécessaires à l'OOBE et les applications d'enrôlement minimales. Les personnalisations propres au lycée, aux salles ou aux rôles restent hors de l'ISO et sont appliquées après installation depuis un manifeste serveur signé.

Cette recommandation reste valide avec le socle Preseed modifié. Elle reste à confirmer définitivement par une installation VM répétable avec:

- DHCP et miroir Debian joignable sans écran interactif de configuration;
- démarrage graphique SDDM;
- X11 actif;
- OOBE disponible;
- taille ISO mesurée;
- durée d'installation mesurée;
- journal d'échec APT exploitable.

Une variante où Plasma serait entièrement récupéré après l'enrôlement n'est pas adoptée. Les thèmes, logiciels lourds, restrictions spécifiques, Veyon, Samba et applications d'établissement peuvent néanmoins être changés après installation depuis le serveur.

## 5. Décision provisoire — installateur

**Choix recommandé pour poursuivre:** Preseed reste le chemin de référence; Calamares reste un prototype isolé.

Critères de comparaison obligatoires:

- installation complète hors réseau;
- aucune question Debian superflue;
- partitionnement et redémarrage répétables;
- BIOS et UEFI;
- taille ISO;
- durée d'installation;
- intégration du même payload OOBE, compte temporaire et finalisation;
- diagnostics lisibles lors d'une panne;
- sécurité des mots de passe et de la configuration finale.

Calamares ne sera retenu que si le prototype prouve ces critères sans perdre les garanties de la chaîne actuelle.

## 6. Critères de sortie de l'étape 0

- [x] état Git et ISO de référence conservés;
- [x] une VM neuve atteint l'installateur sans écran DHCP ou miroir observé;
- [x] inventaire réel vérifié sur une installation complète (socle Plasma minimal `sddm`, `xorg`, `plasma-desktop`, dépendances Python OOBE);
- [x] Plasma minimal décidé et validé sur VM neuve;
- [ ] prototype Calamares isolé exécuté;
- [ ] comparaison Preseed/Calamares documentée;
- [ ] décisions finales promues en ADR.

## 8. Validation de l'étape 1 (24 novembre 2026)

- [x] **Étape 1 validée sur deux VM neuves (`LyuX-Step1-Val` et `LyuX-Step1-Val2`)** :
  - **Cause racine résolue** : dans `preseed/late_command`, `dpkg-query -W -f="${Status}"` était interprété par `bash -c '...'` (expansion vide de `${Status}`), provoquant un échec `exit 1`, puis un `coredump` de `debconf` lors de `db_subst preseed/command_failed` et le redémarrage en boucle de `finish-install`. Corrigé par `-f="\${Status}"`, `chmod 644` sur `lyux-enrollment.service`, `d-i cdrom-detect/eject boolean true`, et normalisation CRLF dans `build-client-iso.sh`.
  - **ISO validée** : `lyux-client-installer-latest.iso` (1 052 583 936 octets, SHA-256 `98E620980FBE70CC43A0A616A771FFE29197A715D42B634B06D461CA3EDC549E`, `verify-client-iso.sh` OK).
  - **Preuves VM (`LyuX-Step1-Val` et `LyuX-Step1-Val2`)** : installation 100 % automatique sur disque vierge 32 Go sans écran DHCP/miroir, GRUB installé, DVD éjecté (`emptydrive`), reboot automatique depuis le disque, arrivée sur SDDM + Xorg (`VideoMode=1280,800,32`), `lyux-enrollment.service` activé (`enabled`), `/etc/lyux/first-boot.flag` présent sans faux dossier d'enrôlement, et les 6 marqueurs `/var/lib/lyux/step-*` à `OK`.
  - **Étape 2** : validée le 24 novembre 2026 sur `LyuX-Step1-Val` et via les suites automatisées (`lyux-desktop/tests`, `lyux-server/tests/test_enrollment_contract.py`).

## 9. Validation de l'étape 2 — OOBE et contrat d'enrôlement (24 novembre 2026)

- [x] **Séquence systemd / X11** : `lyux-enrollment.service` (`ConditionPathExists=/etc/lyux/first-boot.flag`, `After=network-online.target`, `Before=display-manager.service sddm.service`) lance `xinit` + `lyux-oobe-session.sh` (`QT_QPA_PLATFORM=xcb`, `LYUX_OOBE_EXIT_ON_ENROLL=1`) avant SDDM, puis rend la main à SDDM après enrôlement confirmé et se désactive.
- [x] **Réseau & découverte sans IP figée** : `lyux-net-setup.sh` (DHCP ou statique via `/etc/lyux/network-static.conf`) et `discovery.py` (passerelle par défaut + `LYUX_SERVER_URL`, validation stricte d'URL) distinguent `network-error`, `server-unreachable`, `awaiting-authorization`, `authorized` et `enrolled`.
- [x] **Contrat API & idempotence** : `POST /api/v1/enroll/client-enroll`, `GET /api/v1/enroll/roles`, `GET /api/v1/enroll/status/{client_id}` valident le catalogue serveur (`building_id`, `room_id`, `role`), signent le profil en HMAC-SHA256, et dédupliquent via `client_id` / `mac_address` sans créer de doublon ni d'état `enrolled.json` avant confirmation serveur.
- [x] **Preuves VM (`LyuX-Step1-Val`)** : captures de l'OOBE X11 avant SDDM (`step2-06-tty1.png`), serveur absent (`step2-07-server-absent.png`), serveur verrouillé (`step2-08-server-locked.png`), serveur autorisé (`step2-09-server-authorized.png`), sélection catalogue (`step2-11-batc-c14.png`), confirmation `C14-PC03` (`step2-12-enrolling.png`), transition vers SDDM (`step2-13-sddm-after-oobe.png`) et état final (`step2-14-post-enroll-state.png`).

## 10. Validation de l'étape 3 — Manifeste de profil, Ed25519 et maintenance locale (25 novembre 2026)

- [x] **Schéma & chaîne Ed25519** : [SCHEMA_MANIFESTE_PROFIL.md](SCHEMA_MANIFESTE_PROFIL.md), `profile_trust.py` (clés Ed25519 hors dépôt Git, rotation avec clé de secours, signature détachée).
- [x] **Registre serveur & endpoints** : `release_registry.py`, `GET /api/v1/client/profile-manifest`, `GET /api/v1/client/public-keys`, `POST /api/v1/releases/{id}/{sign,publish,revoke,rollback}`, journal d'audit.
- [x] **Vérification client & rollback** : `profile_manifest.py` (états `pending` -> `applied` / `rolling_back`, vérification Ed25519 + SHA-256 + compatibilité + portée avant application).
- [x] **Maintenance locale sécurisée** : `maintenance.py` (FIDO2/U2F, jeton USB Ed25519 lié au numéro de série `udev`, mot de passe admin PBKDF2).
- [x] **Admin UI Paquets/Versions** : `Paquets/index.jsx`, `ReleaseDetail.jsx`, `ManifestPanel.jsx` connectés aux endpoints réels (publication bloquée sans signature Ed25519).
- [x] **Tests** : `lyux-desktop/tests` (`26 passed`), `lyux-server` Step 3 (`12 passed`), `os-builder/tests/e2e` (`125 passed`), build `admin-ui` (`vite build` OK). Validation complémentaire en VM/conteneur Debian 13 à exécuter une fois Docker Desktop démarré.

## 11. Implémentation de l'étape 4 — Dépôts APT signés et application de profils (25 novembre 2026)

- [x] **Dépôt APT pilote signé** : `apt_repo.py` (`.deb` `lyux-profile-standard_1.0.0_all.deb`, `Packages`, `Packages.gz`, `Release`, `Release.ed25519`, endpoints `/api/v1/apt-repo/...`).
- [x] **Rapport client & catalogue strict** : `POST /api/v1/client/profile-report`, `APPROVED_DEBIAN_PACKAGES`, `APPROVED_FLATPAKS`, interdiction `command`/`script`.
- [x] **Applicateur client & rollback** : `profile_applier.py` (vérification Ed25519 + SHA-256, `dpkg -i`, configuration SDDM/KDE X11 sans Wayland, idempotence, rollback automatique sur échec).
- [ ] **Validation VM complète hors-ligne (sans Internet WAN)** : à exécuter sur `LyuX-Server` + `LyuX-Client-Setup` pour clôturer définitivement la porte de sortie VM de l'étape 4.

Tant que les cases finales ne sont pas cochées, l'étape 0 reste en cours et aucune migration Calamares ni réduction du bureau ne doit être engagée.

## 7. Premier ordre d'exécution

1. Exécuter les tests de l'étape 0 sans modification des scripts;
2. valider l'inventaire réel sur une VM vierge;
3. comparer Preseed et Calamares sur VM isolées;
4. documenter la décision finale sous forme d'ADR;
5. passer à l'étape 1 uniquement après répétabilité d'une VM neuve.
