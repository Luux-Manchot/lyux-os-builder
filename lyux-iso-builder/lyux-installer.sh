#!/usr/bin/env bash
# ==============================================================================
# Programme d'Installation et Configuration Autonome LyuX Client OS
# ==============================================================================
set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

TITLE="🐧 Installation & Configuration de LyuX Client OS"
INSTALL_LOG="/tmp/lyux-installer.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$INSTALL_LOG"
}

# Initialiser le journal
echo "=== Démarrage de l'installation LyuX OS ===" > "$INSTALL_LOG"

# Initialisation et réveil immédiat des interfaces réseau
log "Activation et configuration des interfaces réseau..."
for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^en|^eth'); do
    ip link set "$iface" up 2>/dev/null || true
done

# Garantir une présence IP sur le réseau interne LyuX (192.168.10.0/24)
if ! ip -4 addr show 2>/dev/null | grep -q "192.168.10."; then
    INT_IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^enp0s3|^eth0' | head -n1 || echo "")
    if [ -n "$INT_IFACE" ]; then
        log "Attribution IP de découverte (192.168.10.55/24) sur $INT_IFACE..."
        ip addr add 192.168.10.55/24 dev "$INT_IFACE" 2>/dev/null || true
        ip link set "$INT_IFACE" up 2>/dev/null || true
    fi
fi

# 1. Écran de Bienvenue
whiptail --title "$TITLE" --msgbox \
"Bienvenue dans l'assistant d'installation autonome de LyuX OS.\n\nCe programme va configurer ce poste de travail et installer l'image système LyuX avec son environnement graphique, ses profils élèves/profs et sa liaison au serveur d'établissement.\n\nAppuyez sur Entrée pour commencer." \
14 70

# 2. Détection / Connexion obligatoire au Serveur LyuX Hub
SERVER_IP=""

while true; do
    CONNECT_MODE=$(whiptail --title "$TITLE" --menu \
    "Connexion au serveur central LyuX Hub :\n\nL'installation et la configuration de ce poste nécessitent une liaison directe avec le serveur central pour récupérer dynamiquement le catalogue des bâtiments, salles et attributions.\n\nChoisissez la méthode de découverte :" 16 70 2 \
    "auto" "Détection automatique (Scanner le réseau local)" \
    "manual" "Saisie manuelle (Entrer l'adresse IP du serveur)" \
    3>&1 1>&2 2>&3) || CONNECT_MODE="auto"

    CANDIDATE_IP=""

    if [ "$CONNECT_MODE" = "auto" ]; then
        log "Recherche active du serveur LyuX Hub sur le réseau..."
        
        # Liste ordonnée de sondage
        PROBE_LIST=("192.168.10.1")
        DEF_GW=$(ip route show default 2>/dev/null | awk '{print $3}' | head -n1 || echo "")
        [ -n "$DEF_GW" ] && PROBE_LIST+=("$DEF_GW")
        if getent hosts lyux-server >/dev/null 2>&1; then
            PROBE_LIST+=($(getent hosts lyux-server | awk '{print $1}' | head -n1))
        fi

        for ip_probe in "${PROBE_LIST[@]}"; do
            if curl -s -m 2 "http://$ip_probe:8000/api/v1/parc/status" >/dev/null 2>&1; then
                CANDIDATE_IP="$ip_probe"
                break
            fi
        done
    else
        CANDIDATE_IP=$(whiptail --title "$TITLE" --inputbox \
        "Saisissez l'adresse IP du serveur central LyuX Hub :" 10 60 "192.168.10.1" \
        3>&1 1>&2 2>&3) || CANDIDATE_IP=""
    fi

    # Vérification stricte : le serveur DOIT répondre sur son API
    if [ -n "$CANDIDATE_IP" ] && curl -s -m 3 "http://$CANDIDATE_IP:8000/api/v1/parc/status" >/dev/null 2>&1; then
        SERVER_IP="$CANDIDATE_IP"
        SERVER_STATUS="En ligne et connecté ($SERVER_IP)"
        log "Serveur LyuX Hub validé avec succès sur $SERVER_IP !"
        whiptail --title "$TITLE" --msgbox \
        "✅ Connexion au serveur central réussie !\n\nServeur LyuX Hub : $SERVER_IP\n\nL'assistant va maintenant charger le catalogue des bâtiments et salles depuis le serveur." \
        11 65
        break
    else
        # Le serveur est injoignable -> BLOCAGE STRICT
        log "Échec de connexion au serveur (${CANDIDATE_IP:-aucun serveur détecté})"
        whiptail --title "❌ SERVEUR INTROUVABLE" --msgbox \
        "Impossible de joindre le serveur central LyuX Hub (${CANDIDATE_IP:-aucun serveur détecté}).\n\n⚠️ SÉCURITÉ : Sans serveur central connecté, la configuration du poste client ne peut pas continuer car les bâtiments et salles proviennent obligatoirement du serveur central.\n\nVérifiez que le serveur LyuX est allumé et connecté au réseau, puis appuyez sur Entrée pour réessayer." \
        14 70
    fi
done

# 3. Récupération dynamique des Bâtiments depuis le serveur
log "Interrogation de l'API bâtiments : http://$SERVER_IP:8000/api/v1/buildings"
BUILDINGS_JSON=$(curl -s -m 5 "http://$SERVER_IP:8000/api/v1/buildings" || echo "[]")

parse_json_buildings() {
    if command -v jq >/dev/null 2>&1; then
        echo "$1" | jq -r '.[] | "\(.id)|\(.name)"' 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, json; [print(f\"{b.get('id','')}|{b.get('name','')}\") for b in json.loads(sys.stdin.read())]" <<< "$1" 2>/dev/null || true
    fi
}

BUILDING_ARGS=()
FIRST=1
while IFS='|' read -r b_id b_name; do
    if [ -n "$b_id" ]; then
        STATUS="OFF"
        if [ "$FIRST" -eq 1 ]; then
            STATUS="ON"
            FIRST=0
        fi
        BUILDING_ARGS+=("$b_id" "$b_name" "$STATUS")
    fi
done < <(parse_json_buildings "$BUILDINGS_JSON")

if [ ${#BUILDING_ARGS[@]} -eq 0 ]; then
    whiptail --title "❌ ERREUR API SERVEUR" --msgbox \
    "Le serveur central n'a renvoyé aucun bâtiment enregistré.\nVeuillez configurer au moins un bâtiment sur le serveur central LyuX." 10 65
    exit 1
fi

BUILDING=$(whiptail --title "$TITLE" --radiolist \
"Sélectionnez le bâtiment de rattachement (fourni par le serveur central) :" 16 68 8 \
"${BUILDING_ARGS[@]}" \
3>&1 1>&2 2>&3)

if [ -z "$BUILDING" ]; then
    BUILDING="${BUILDING_ARGS[0]}"
fi

# 4. Récupération dynamique des Salles depuis le serveur
log "Interrogation de l'API salles : http://$SERVER_IP:8000/api/v1/rooms"
ROOMS_JSON=$(curl -s -m 5 "http://$SERVER_IP:8000/api/v1/rooms" || echo "[]")

parse_json_rooms() {
    if command -v jq >/dev/null 2>&1; then
        echo "$1" | jq -r '.[] | "\(.id)|\(.name)|\(.building_id)"' 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, json; [print(f\"{r.get('id','')}|{r.get('name','')}|{r.get('building_id','')}\") for r in json.loads(sys.stdin.read())]" <<< "$1" 2>/dev/null || true
    fi
}

ROOM_ARGS=()
FIRST=1
while IFS='|' read -r r_id r_name r_bid; do
    if [ "$r_bid" = "$BUILDING" ] || [ -z "$r_bid" ]; then
        STATUS="OFF"
        if [ "$FIRST" -eq 1 ]; then
            STATUS="ON"
            FIRST=0
        fi
        ROOM_ARGS+=("$r_id" "Salle $r_name" "$STATUS")
    fi
done < <(parse_json_rooms "$ROOMS_JSON")

# Si aucune salle n'est spécifiquement rattachée au bâtiment, proposer toutes les salles disponibles
if [ ${#ROOM_ARGS[@]} -eq 0 ]; then
    FIRST=1
    while IFS='|' read -r r_id r_name r_bid; do
        STATUS="OFF"
        if [ "$FIRST" -eq 1 ]; then
            STATUS="ON"
            FIRST=0
        fi
        ROOM_ARGS+=("$r_id" "Salle $r_name" "$STATUS")
    done < <(parse_json_rooms "$ROOMS_JSON")
fi

if [ ${#ROOM_ARGS[@]} -eq 0 ]; then
    whiptail --title "❌ ERREUR API SERVEUR" --msgbox \
    "Le serveur central n'a renvoyé aucune salle pour le bâtiment $BUILDING.\nVeuillez créer la salle correspondante sur le serveur central." 10 65
    exit 1
fi

ROOM=$(whiptail --title "$TITLE" --radiolist \
"Sélectionnez la salle (fournie par le serveur central) :" 16 68 8 \
"${ROOM_ARGS[@]}" \
3>&1 1>&2 2>&3)

if [ -z "$ROOM" ]; then
    ROOM="${ROOM_ARGS[0]}"
fi

# 5. Suggestion dynamique du Nom du Poste par le serveur
log "Demande de suggestion de nom d'hôte : http://$SERVER_IP:8000/api/v1/enroll/suggest-hostname?room_id=$ROOM"
SUGGEST_JSON=$(curl -s -m 5 "http://$SERVER_IP:8000/api/v1/enroll/suggest-hostname?room_id=$ROOM" || echo "{}")
if command -v jq >/dev/null 2>&1; then
    SERVER_SUGGESTED=$(echo "$SUGGEST_JSON" | jq -r '.suggested_hostname // empty' 2>/dev/null || echo "")
else
    SERVER_SUGGESTED=$(python3 -c "import sys, json; print(json.loads(sys.stdin.read()).get('suggested_hostname', ''))" <<< "$SUGGEST_JSON" 2>/dev/null || echo "")
fi

if [ -z "$SERVER_SUGGESTED" ]; then
    SERVER_SUGGESTED="${ROOM}-PC02"
fi

HOSTNAME=$(whiptail --title "$TITLE" --inputbox \
"Nom d'ordinateur pour ce poste (suggéré par le serveur central) :" 10 65 "$SERVER_SUGGESTED" \
3>&1 1>&2 2>&3)

HOSTNAME="${HOSTNAME:-$SERVER_SUGGESTED}"

# 6. Choix et Configuration du Mode Réseau (DHCP vs IP Statique)
CURRENT_IP=$(ip -4 addr show scope global 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1 || echo "")
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP="192.168.10.22"
fi

NET_MODE=$(whiptail --title "$TITLE" --radiolist \
"Sélectionnez le mode d'attribution réseau pour ce poste :" 14 65 2 \
"dhcp" "DHCP (Attribution dynamique automatique)" ON \
"static" "IP Statique (Définir manuellement l'adresse IP)" OFF \
3>&1 1>&2 2>&3)

if [ -z "$NET_MODE" ]; then
    NET_MODE="dhcp"
fi

CLIENT_IP=""
CLIENT_MASK="24"
CLIENT_GW="$SERVER_IP"
CLIENT_DNS="$SERVER_IP, 1.1.1.1"

if [ "$NET_MODE" = "static" ]; then
    CLIENT_IP=$(whiptail --title "$TITLE" --inputbox \
    "Adresse IP fixe de ce poste :" 10 60 "$CURRENT_IP" \
    3>&1 1>&2 2>&3)
    if [ -z "$CLIENT_IP" ]; then
        CLIENT_IP="$CURRENT_IP"
    fi

    CLIENT_GW=$(whiptail --title "$TITLE" --inputbox \
    "Passerelle par défaut (Gateway / Routeur) :" 10 60 "$SERVER_IP" \
    3>&1 1>&2 2>&3)
    if [ -z "$CLIENT_GW" ]; then
        CLIENT_GW="$SERVER_IP"
    fi

    CLIENT_DNS=$(whiptail --title "$TITLE" --inputbox \
    "Serveurs DNS (séparés par une virgule) :" 10 60 "$SERVER_IP, 1.1.1.1" \
    3>&1 1>&2 2>&3)
    if [ -z "$CLIENT_DNS" ]; then
        CLIENT_DNS="$SERVER_IP, 1.1.1.1"
    fi
    NET_SUMMARY="IP Statique ($CLIENT_IP)"
else
    NET_SUMMARY="DHCP Automatique"
fi

# 7. Détection et sélection du disque cible
DISKS=()
while read -r dev size model; do
    if [[ "$dev" != *"loop"* && "$dev" != *"sr"* ]]; then
        DISKS+=("/dev/$dev" "$size - $model")
    fi
done < <(lsblk -d -n -o NAME,SIZE,MODEL | grep -v "sr0" || true)

if [ ${#DISKS[@]} -eq 0 ]; then
    TARGET_DISK="/dev/sda"
else
    TARGET_DISK="${DISKS[0]}"
fi

if (whiptail --title "⚠️ CONFIRMATION D'INSTALLATION" --yesno \
"RÉSUMÉ DE LA CONFIGURATION :\n\n- Serveur  : $SERVER_IP ($SERVER_STATUS)\n- Bâtiment : Bâtiment $BUILDING\n- Salle    : Salle $ROOM\n- Nom PC   : $HOSTNAME\n- Réseau   : $NET_SUMMARY\n- Disque   : $TARGET_DISK\n\nATTENTION : Le disque $TARGET_DISK sera intégralement effacé et partitionné pour installer LyuX Client OS.\n\nSouhaitez-vous lancer l'installation maintenant ?" \
19 68); then
    log "Lancement de l'installation par l'utilisateur."
else
    whiptail --title "$TITLE" --msgbox "Installation annulée par l'utilisateur." 8 50
    exit 0
fi

# 8. Fonction de Déploiement avec suivi précis
deploy_system() {
    echo 5; sleep 1

    TARGET_MNT="/target"
    log "Démontage préalable de toute partition existante..."
    umount -R "$TARGET_MNT" 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    for p in "${TARGET_DISK}"* ; do
        umount -l "$p" 2>/dev/null || true
    done

    echo 10; sleep 1
    log "Écriture de la table de partition MBR sur $TARGET_DISK..."
    dd if=/dev/zero of="$TARGET_DISK" bs=1M count=10 conv=notrunc >> "$INSTALL_LOG" 2>&1 || true
    parted -s "$TARGET_DISK" mklabel msdos >> "$INSTALL_LOG" 2>&1
    parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100% >> "$INSTALL_LOG" 2>&1
    parted -s "$TARGET_DISK" set 1 boot on >> "$INSTALL_LOG" 2>&1

    sync
    udevadm settle --timeout=5 2>/dev/null || sleep 2
    partprobe "$TARGET_DISK" >> "$INSTALL_LOG" 2>&1 || true
    sleep 2

    PART_ROOT="${TARGET_DISK}1"
    if [[ "$TARGET_DISK" == *"nvme"* ]]; then
        PART_ROOT="${TARGET_DISK}p1"
    fi

    # Vérification et attente explicite du nœud de périphérique
    for i in {1..10}; do
        if [ -b "$PART_ROOT" ]; then
            break
        fi
        log "Attente du périphérique $PART_ROOT (essai $i/10)..."
        mknod "$PART_ROOT" b 8 1 2>/dev/null || true
        udevadm settle --timeout=2 2>/dev/null || sleep 1
    done

    echo 20; sleep 1
    log "Formatage ext4 de $PART_ROOT..."
    mkfs.ext4 -F -F -L "LYUX_ROOT" "$PART_ROOT" >> "$INSTALL_LOG" 2>&1

    sync
    udevadm settle --timeout=5 2>/dev/null || sleep 2
    sleep 1

    mkdir -p "$TARGET_MNT"
    log "Montage de $PART_ROOT sur $TARGET_MNT..."
    mount "$PART_ROOT" "$TARGET_MNT" >> "$INSTALL_LOG" 2>&1

    echo 30; sleep 1
    log "Recherche du fichier image SquashFS..."
    SQUASHFS_SRC=""
    for p in \
        /run/live/medium/live/filesystem.squashfs \
        /live/filesystem.squashfs \
        /cdrom/live/filesystem.squashfs \
        /opt/lyux/lyux-master.squashfs \
        /opt/lyux/iso-build/root/live/filesystem.squashfs; do
        if [ -f "$p" ]; then
            SQUASHFS_SRC="$p"
            break
        fi
    done

    if [ -z "$SQUASHFS_SRC" ]; then
        SQUASHFS_SRC=$(find /run /live /cdrom /mnt /media -name "*.squashfs" 2>/dev/null | grep -E "filesystem|master" | head -n1 || echo "")
    fi

    if [ -z "$SQUASHFS_SRC" ]; then
        log "ERREUR FATALE : Aucun fichier SquashFS trouvé !"
        return 1
    fi

    if ! command -v unsquashfs >/dev/null 2>&1; then
        log "ERREUR FATALE : L'utilitaire unsquashfs est introuvable !"
        return 1
    fi

    echo 40
    log "Extraction de $SQUASHFS_SRC vers $TARGET_MNT..."
    if ! unsquashfs -f -d "$TARGET_MNT" "$SQUASHFS_SRC" >> "$INSTALL_LOG" 2>&1; then
        log "ERREUR FATALE : Échec de l'extraction de $SQUASHFS_SRC !"
        return 1
    fi

    EXTRACTED_SIZE=$(du -sm "$TARGET_MNT" 2>/dev/null | awk '{print $1}')
    log "Taille extraite sur la cible : ${EXTRACTED_SIZE} Mo"
    if [ "${EXTRACTED_SIZE:-0}" -lt 500 ]; then
        log "ERREUR FATALE : Déploiement incomplet (${EXTRACTED_SIZE} Mo extraits) !"
        return 1
    fi

    echo 75; sleep 1
    log "Configuration personnalisée de $HOSTNAME..."
    echo "$HOSTNAME" > "$TARGET_MNT/etc/hostname"

    cat << EOF > "$TARGET_MNT/etc/hosts"
127.0.0.1   localhost
127.0.1.1   $HOSTNAME.lyux.lan $HOSTNAME

# LyuX Hub Central
$SERVER_IP    lyux-server.lyux.lan lyux-server
EOF

    # Configuration NetworkManager
    mkdir -p "$TARGET_MNT/etc/NetworkManager/system-connections"
    rm -f "$TARGET_MNT/etc/NetworkManager/system-connections/"*

    if [ "$NET_MODE" = "static" ]; then
        cat << EOF > "$TARGET_MNT/etc/NetworkManager/system-connections/lyux-lan.nmconnection"
[connection]
id=lyux-lan
type=ethernet
autoconnect=true

[ethernet]

[ipv4]
address1=${CLIENT_IP}/${CLIENT_MASK},${CLIENT_GW}
dns=${CLIENT_DNS//, /;};
method=manual

[ipv6]
method=ignore
EOF
    else
        cat << EOF > "$TARGET_MNT/etc/NetworkManager/system-connections/lyux-lan.nmconnection"
[connection]
id=lyux-lan
type=ethernet
autoconnect=true

[ethernet]

[ipv4]
method=auto

[ipv6]
method=ignore
EOF
    fi
    chmod 600 "$TARGET_MNT/etc/NetworkManager/system-connections/lyux-lan.nmconnection"

    # Génération propre de /etc/fstab (UUID réel et NFS LyuX)
    ROOT_UUID=$(blkid -c /dev/null -s UUID -o value "$PART_ROOT" 2>/dev/null || lsblk -no UUID "$PART_ROOT" 2>/dev/null || echo "")
    if [ -n "$ROOT_UUID" ]; then
        ROOT_SPEC="UUID=$ROOT_UUID"
    else
        ROOT_SPEC="LABEL=LYUX_ROOT"
    fi
    cat << EOF > "$TARGET_MNT/etc/fstab"
# /etc/fstab: static file system information for LyuX Client OS
$ROOT_SPEC /               ext4    errors=remount-ro 0       1
$SERVER_IP:/srv/samba/homes /srv/samba/homes nfs rw,sync,nosuid,nodev,_netdev 0 0
EOF

    # Nettoyage des résidus du mode Live dans le système installé
    rm -rf "$TARGET_MNT/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true
    rm -f "$TARGET_MNT/usr/local/bin/lyux-installer" 2>/dev/null || true
    rm -f "$TARGET_MNT/etc/systemd/system/vboxadd.service" 2>/dev/null || true
    rm -f "$TARGET_MNT/etc/systemd/system/vboxadd-service.service" 2>/dev/null || true
    rm -f "$TARGET_MNT/etc/systemd/system/sddm.service" 2>/dev/null || true
    sed -i '/lyux-installer/d' "$TARGET_MNT/root/.profile" "$TARGET_MNT/root/.bashrc" "$TARGET_MNT/root/.bash_profile" 2>/dev/null || true
    
    # Supprimer l'attente d'hibernation / swap fantôme
    mkdir -p "$TARGET_MNT/etc/initramfs-tools/conf.d"
    echo "RESUME=none" > "$TARGET_MNT/etc/initramfs-tools/conf.d/resume" 2>/dev/null || true

    # Métadonnées locales d'enrôlement et Version Système LyuX
    ACTUAL_IP="${CLIENT_IP:-$CURRENT_IP}"
    mkdir -p "$TARGET_MNT/etc/lyux"
    cat << EOF > "$TARGET_MNT/etc/lyux/enrollment.json"
{
  "hostname": "$HOSTNAME",
  "building": "$BUILDING",
  "room": "$ROOM",
  "server_ip": "$SERVER_IP",
  "network_mode": "$NET_MODE",
  "ip": "$ACTUAL_IP",
  "enrolled_at": "$(date -Iseconds)"
}
EOF

    # Identification officielle de Version LyuX
    LYUX_SYS_VERSION="1.0.0"
    LYUX_SYS_BUILD="$(date +%Y%m%d)"
    cat << EOF > "$TARGET_MNT/etc/lyux/version"
LYUX_VERSION="$LYUX_SYS_VERSION"
LYUX_BUILD="$LYUX_SYS_BUILD"
LYUX_EDITION="Client"
LYUX_BASE="Debian GNU/Linux 13 (Trixie)"
EOF

    # Personnalisation de /etc/os-release pour les informations système KDE / Info Center
    cat << EOF > "$TARGET_MNT/etc/os-release"
PRETTY_NAME="LyuX Client OS $LYUX_SYS_VERSION"
NAME="LyuX Client OS"
VERSION_ID="$LYUX_SYS_VERSION"
VERSION="$LYUX_SYS_VERSION (Trixie)"
VERSION_CODENAME=trixie
ID=lyux
ID_LIKE=debian
HOME_URL="https://flowcrea.fr"
SUPPORT_URL="http://$SERVER_IP:8000"
BUG_REPORT_URL="http://$SERVER_IP:8000"
EOF

    # Script utilitaire d'information système lyux-info
    cat << 'EOF' > "$TARGET_MNT/usr/local/bin/lyux-info"
#!/bin/bash
if [ -f /etc/lyux/version ]; then
    source /etc/lyux/version
fi
echo "================================================"
echo "  LyuX Client OS - Version $LYUX_VERSION (Build $LYUX_BUILD)"
echo "  Architecture LyuX Éducation & Parc Lycée"
echo "================================================"
if [ -f /etc/lyux/enrollment.json ]; then
    echo "Métadonnées d'enrôlement :"
    cat /etc/lyux/enrollment.json
fi
echo "================================================"
EOF
    chmod +x "$TARGET_MNT/usr/local/bin/lyux-info" 2>/dev/null || true

    echo 85; sleep 1
    log "Installation du chargeur de démarrage GRUB sur $TARGET_DISK..."
    mkdir -p "$TARGET_MNT/boot/grub"

    # 1. Écriture du MBR et des modules GRUB directement depuis l'hôte
    log "Exécution de grub-install sur $TARGET_DISK (MBR)..."
    /usr/sbin/grub-install --target=i386-pc --recheck --boot-directory="$TARGET_MNT/boot" "$TARGET_DISK" >> "$INSTALL_LOG" 2>&1 || \
    grub-install --target=i386-pc --recheck --boot-directory="$TARGET_MNT/boot" "$TARGET_DISK" >> "$INSTALL_LOG" 2>&1

    # 2. Mise à jour de l'UUID racine dans grub.cfg
    if [ -n "$ROOT_UUID" ]; then
        log "Mise à jour de l'UUID ($ROOT_UUID) dans /boot/grub/grub.cfg..."
        sed -i "s/53064677-3f2f-44c9-8bac-99a48774024c/$ROOT_UUID/g" "$TARGET_MNT/boot/grub/grub.cfg" 2>/dev/null || true
    fi

    # 3. Ajout de la sortie console série ttyS0 dans grub.cfg pour journalisation hôte
    sed -i 's|quiet splash|quiet splash console=tty0 console=ttyS0,115200n8|g' "$TARGET_MNT/boot/grub/grub.cfg" 2>/dev/null || true

    # 4. Bind mounts pour opérations de finalisation
    mount --bind /dev "$TARGET_MNT/dev"
    mount --bind /dev/pts "$TARGET_MNT/dev/pts" 2>/dev/null || true
    mount --bind /proc "$TARGET_MNT/proc"
    mount --bind /sys "$TARGET_MNT/sys"
    mount --bind /run "$TARGET_MNT/run" 2>/dev/null || true

    # 5. Activation graphique SDDM
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin chroot "$TARGET_MNT" systemctl set-default graphical.target >> "$INSTALL_LOG" 2>&1 || true
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin chroot "$TARGET_MNT" systemctl enable sddm >> "$INSTALL_LOG" 2>&1 || true

    # 5b. Installation automatique de lyux-desktop-core depuis le serveur APT LyuX
    # Configure PAM + NSS + timer de sync utilisateurs dès l'installation
    log "Installation de lyux-desktop-core depuis le serveur LyuX ($SERVER_IP)..."
    DEB_URL="http://$SERVER_IP:8000/api/v1/apt-repo/pool/main/lyux-desktop-core_$(cat /cdrom/lyux-payload/enrollment/../../../VERSION 2>/dev/null || echo '0.5.0-beta.2')_all.deb"
    DEB_TMP="$TARGET_MNT/tmp/lyux-desktop-core.deb"
    if curl -sf --connect-timeout 5 -o "$DEB_TMP" "$DEB_URL" 2>>"$INSTALL_LOG"; then
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin chroot "$TARGET_MNT" dpkg -i /tmp/lyux-desktop-core.deb >> "$INSTALL_LOG" 2>&1 || true
        rm -f "$DEB_TMP"
        log "lyux-desktop-core installé et PAM/NSS configurés."
    else
        log "AVERTISSEMENT : impossible de télécharger lyux-desktop-core depuis $DEB_URL — PAM/NSS à configurer après enrôlement."
    fi

    echo 95; sleep 1
    log "Notification API au serveur central ($SERVER_IP)..."
    curl -s -X POST "http://$SERVER_IP:8000/api/v1/parc/enroll" \
        -H "Content-Type: application/json" \
        -d "{\"hostname\": \"$HOSTNAME\", \"building\": \"$BUILDING\", \"room\": \"$ROOM\", \"network_mode\": \"$NET_MODE\", \"ip\": \"$ACTUAL_IP\"}" >> "$INSTALL_LOG" 2>&1 || true

    # Démontage propre
    log "Démontage de la cible..."
    sync
    umount -R "$TARGET_MNT" >> "$INSTALL_LOG" 2>&1 || true

    echo 100; sleep 1
    return 0
}

# Exécuter le déploiement sous jauge de progression
PIPE_ERR=0
deploy_system | whiptail --title "$TITLE" --gauge "Déploiement de LyuX Client OS en cours...\nVeuillez patienter pendant l'écriture sur le disque." 8 68 0 || PIPE_ERR=$?

if [ "$PIPE_ERR" -ne 0 ] || [ ! -f "$INSTALL_LOG" ]; then
    whiptail --title "❌ ÉCHEC DU DÉPLOIEMENT" --msgbox \
    "Une erreur est survenue pendant l'installation sur le disque $TARGET_DISK.\n\nDernières lignes du journal :\n$(tail -n 12 "$INSTALL_LOG" 2>/dev/null || echo "Aucun log")\n\nAppuyez sur Entrée pour ouvrir une console de diagnostic." \
    16 72
    clear
    echo "=== ERREUR D'INSTALLATION - CONSOLE DE SECOURS ==="
    tail -n 30 "$INSTALL_LOG"
    echo "=================================================="
    echo "Tapez 'exit' pour relancer l'assistant."
    bash
    exit 1
fi

# 9. Écran Final de Succès & Arrêt Propre
whiptail --title "$TITLE" --msgbox \
"🎉 Félicitations ! L'installation de LyuX Client OS est terminée avec succès.\n\n- Nom du poste : $HOSTNAME\n- Bâtiment / Salle : Bâtiment $BUILDING (Salle $ROOM)\n- Réseau : $NET_SUMMARY\n- Serveur LyuX : $SERVER_IP\n\nLa machine va maintenant s'éteindre.\nVeuillez retirer la clé USB ou déconnecter l'ISO dans VirtualBox pour démarrer directement sur votre nouveau système LyuX !" \
17 72

poweroff
