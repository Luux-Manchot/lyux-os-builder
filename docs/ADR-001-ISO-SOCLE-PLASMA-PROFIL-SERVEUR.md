# ADR-001 - Socle Plasma minimal dans l'ISO et personnalisation serveur

**Date:** 24 novembre 2026

**Statut:** accepté pour la cible, en attente de validation par VM

## Contexte

L'ISO doit pouvoir démarrer l'OOBE graphique sur un poste vierge, même lorsque le serveur LyuX est indisponible. L'installation Debian utilise DHCP et un miroir Debian ou un proxy APT joignable pour télécharger les paquets du socle.

L'image ne doit pas contenir les choix propres à un établissement. Ceux-ci doivent pouvoir être modifiés après installation sans reconstruire l'ISO.

## Décision

L'ISO cliente contient par défaut un socle KDE Plasma minimal comprenant:

- KDE Plasma compatible avec Debian 13;
- SDDM configuré en X11;
- les dépendances minimales nécessaires à l'assistant d'enrôlement;
- Python et les bibliothèques minimales de l'OOBE;
- le réseau local requis pour joindre le serveur;
- le mécanisme de confiance utilisé pour identifier le serveur;
- aucun identifiant, adresse, salle, thème ou secret propre à un établissement.

Après installation, l'enrôlement récupère auprès du serveur un profil signé décrivant:

- thème, couleurs, fond d'écran, icônes et disposition;
- logiciels Debian ou Flatpak approuvés;
- restrictions Kiosk;
- paramètres Veyon;
- paramètres Samba-AD ou réseaux locaux validés;
- politiques de mise à jour et de cache;
- portée établissement, bâtiment, salle ou rôle.

Le lycée peut changer ces choix après installation à partir du catalogue administrateur validé. Les options ne peuvent pas être des URLs arbitraires, des scripts libres ou des commandes transmises directement au poste.

## Alternatives rejetées

### Plasma entièrement récupéré après enrôlement

Cette option rendrait l'OOBE dépendant de la disponibilité du réseau et du serveur. Elle est rejetée pour le démarrage initial.

### Personnalisation graphique intégrée en dur dans chaque ISO

Cette option empêcherait une seule ISO réellement générique de servir plusieurs établissements. Elle est remplacée par des manifestes de profil versionnés et vérifiables distribués après enrôlement.

## Conséquences

- l'ISO est plus volumineuse qu'une base sans Plasma;
- l'OOBE bénéficie d'un environnement graphique dès le premier démarrage;
- l'installation locale nécessite DHCP et un miroir Debian ou proxy APT joignable; Preseed doit configurer ces éléments sans question interactive;
- le serveur porte les profils établis, les artefacts vérifiés et l'historique d'application;
- les thèmes et applications lourds restent hors du socle de base;
- une erreur du serveur ne remet pas en cause le socle graphique ni l'OOBE.

## Validation requise

- installation complète sur disque vierge avec DHCP et miroir Debian, sans écran de configuration réseau ou miroir;
- redémarrage jusqu'à SDDM;
- X11 actif;
- OOBE disponible avant le bureau normal;
- absence d'écran Debian DHCP ou miroir;
- démarrage de l'OOBE graphique et état récupérable lorsque le serveur LyuX est absent;
- échec explicite si une dépendance obligatoire manque;
- application puis restauration d'un profil serveur pilote;
- changement de profil après installation sans reconstruire l'ISO.

## État

Cette ADR décrit la décision d'architecture retenue pour le prototype. Elle ne ferme pas l'issue d'installation tant que la VM neuve n'a pas démontré l'installation complète, le reboot et l'OOBE.
