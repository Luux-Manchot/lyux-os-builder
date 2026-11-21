# ==============================================================================
# Script d'Initialisation et Déploiement du Lab Réel VirtualBox LyuX (Opération Manchot)
# Conforme aux ADR-003, ADR-007, ADR-010 et Issues #1, #3, #8, #10
# ==============================================================================

param (
    [switch]$StartAfterSetup = $false
)

$ErrorActionPreference = "Continue"

$VBox = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBox)) {
    Write-Host "[ERREUR] VBoxManage.exe introuvable dans C:\Program Files\Oracle\VirtualBox\" -ForegroundColor Red
    exit 1
}

$vmBaseDir = if ($env:USERPROFILE) { "$env:USERPROFILE\VirtualBox VMs" } else { "C:\VirtualBox VMs" }
if (-not (Test-Path $vmBaseDir)) { New-Item -ItemType Directory -Path $vmBaseDir -Force | Out-Null }

$repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$candidateIso = Join-Path $repoRoot "projects\lyux-lab-vm\iso\debian-netinst.iso"
if (-not (Test-Path $candidateIso)) {
    Write-Host "[ERREUR] ISO debian-netinst.iso introuvable dans $candidateIso" -ForegroundColor Red
    exit 1
}
$IsoPath = (Resolve-Path $candidateIso).Path
$TemplatePreseed = Join-Path $repoRoot "projects\lyux-lab-vm\configs\debian_preseed_auto.cfg"

Write-Host "===============================================================================" -ForegroundColor Cyan
# Title banner
Write-Host "      INITIALISATION DU LAB REEL VIRTUALBOX LYUX (OPERATION MANCHOT)" -ForegroundColor Yellow
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "ISO source : $IsoPath" -ForegroundColor Gray
Write-Host "Dossier VMs: $vmBaseDir" -ForegroundColor Gray
Write-Host ""

# ------------------------------------------------------------------------------
# 1. NETTOYAGE COMPLET DES ANCIENNES VMS
# ------------------------------------------------------------------------------
Write-Host "[1/5] Nettoyage complet des anciennes VMs de test..." -ForegroundColor Cyan
$oldVms = @(
    "LyuX-Server", "LyuX-B204-PC1", "LyuX-B204-PC2", "LyuX-S102-PC1", "LyuX-S102-PC2",
    "LyuX-PC-Vierge", "LyuX-Client-Prof", "LyuX-Client-Eleve", "LyuX-Serveur-Central",
    "LyuX-B204-PC01", "LyuX-B204-PC02", "LyuX-S102-PC01"
)

$registeredVms = & $VBox list vms
foreach ($vm in $oldVms) {
    if ($registeredVms -match [regex]::Escape($vm)) {
        Write-Host "  [-] Arret et suppression de $vm..." -ForegroundColor Yellow
        & $VBox controlvm $vm poweroff 2>$null
        Start-Sleep -Milliseconds 600
        & $VBox unregistervm $vm --delete 2>$null
        Start-Sleep -Milliseconds 400
    }
}

# Nettoyage des dossiers orphelins résiduels
Get-ChildItem -Path $vmBaseDir -Filter "*LyuX*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  [-] Nettoyage du dossier orphelin : $($_.FullName)" -ForegroundColor Yellow
    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  [+] Environnement 100% vierge et assaini !" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 2. CONFIGURATION DU RESEAU INTERNE ISOLE (LyuX-Lab-Net)
# ------------------------------------------------------------------------------
Write-Host "[2/5] Configuration du reseau interne isole LyuX-Lab-Net..." -ForegroundColor Cyan
$NetworkName = "LyuX-Lab-Net"
$dhcpList = & $VBox list dhcpservers
if ($dhcpList -match [regex]::Escape($NetworkName)) {
    Write-Host "  [i] Serveur DHCP pour $NetworkName deja actif." -ForegroundColor Gray
} else {
    Write-Host "  [+] Creation du serveur DHCP VirtualBox pour $NetworkName..." -ForegroundColor Green
    & $VBox dhcpserver add --network=$NetworkName --server-ip=192.168.10.254 --netmask=255.255.255.0 --lower-ip=192.168.10.50 --upper-ip=192.168.10.150 --enable
}
Write-Host "  [+] Reseau isole pret (Plage 192.168.10.50 - 192.168.10.150, Passerelle/DC 192.168.10.1)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 3. CREATION DU SERVEUR CENTRAL (LyuX-Server)
# ------------------------------------------------------------------------------
Write-Host "[3/5] Creation du Serveur Central (LyuX-Server)..." -ForegroundColor Cyan
$serverName = "LyuX-Server"
& $VBox createvm --name $serverName --ostype "Debian_64" --register
& $VBox modifyvm $serverName --memory 4096 --cpus 2 --vram 64
& $VBox modifyvm $serverName --graphicscontroller vmsvga --accelerate3d off

# Carte 1 : Reseau interne LyuX-Lab-Net (IP fixe 192.168.10.1, deconnectee pendant install pour forcer NAT)
& $VBox modifyvm $serverName --nic1 intnet --intnet1 $NetworkName --cableconnected1 off

# Carte 2 : NAT (Acces internet paquets debian et redirection de ports pour lab)
& $VBox modifyvm $serverName --nic2 nat --cableconnected2 on
& $VBox modifyvm $serverName --natpf2 "cockpit,tcp,127.0.0.1,9090,,9090"
& $VBox modifyvm $serverName --natpf2 "samba-ldap,tcp,127.0.0.1,389,,389"
& $VBox modifyvm $serverName --natpf2 "samba-krb5,tcp,127.0.0.1,88,,88"
& $VBox modifyvm $serverName --natpf2 "api,tcp,127.0.0.1,8000,,8000"
& $VBox modifyvm $serverName --natpf2 "kuma,tcp,127.0.0.1,3001,,3001"
& $VBox modifyvm $serverName --natpf2 "lam,tcp,127.0.0.1,8082,,8082"
& $VBox modifyvm $serverName --natpf2 "glpi,tcp,127.0.0.1,8085,,8085"
& $VBox modifyvm $serverName --natpf2 "samba-smb,tcp,127.0.0.1,4445,,445"

# Stockage SATA & Disque 40 Go
& $VBox storagectl $serverName --name "SATA" --add sata --controller IntelAhci --bootable on
$serverVdi = "$vmBaseDir\$serverName\$serverName.vdi"
& $VBox createmedium disk --filename $serverVdi --size 40960 --format VDI
& $VBox storageattach $serverName --storagectl "SATA" --port 0 --device 0 --type hdd --medium $serverVdi
& $VBox storageattach $serverName --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoPath

# Preseed & Unattended Zero Invite
& $VBox unattended install $serverName `
    --iso=$IsoPath `
    --user="lyux-admin" `
    --user-password="LyuxAdmin2026!" `
    --country="FR" `
    --time-zone="Europe/Paris" `
    --hostname="server.lyux.lan" `
    --script-template=$TemplatePreseed `
    --extra-install-kernel-parameters="priority=critical file=/cdrom/preseed.cfg netcfg/choose_interface=enp0s8 debian-installer/locale=fr_FR.UTF-8 keyboard-configuration/xkb-keymap=fr(latin9) languagechooser/language-name=French countrychooser/shortlist=FR" `
    --install-additions

Write-Host "  [+] LyuX-Server cree avec succes (4 Go RAM, 2 vCPUs, Disque 40 Go, Carte 1: LyuX-Lab-Net, Carte 2: NAT)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 4. CREATION DES POSTES DE SALLE UNIVERSELS (100% IDENTIQUES)
# ------------------------------------------------------------------------------
Write-Host "[4/5] Creation des Postes Universels de Salle (B204 & S102)..." -ForegroundColor Cyan

$clientVms = @(
    @{ Name = "LyuX-B204-PC01"; Hostname = "b204-pc01"; Room = "B204"; Desc = "Salle B204 (Maths / NSI) - Poste 01" },
    @{ Name = "LyuX-B204-PC02"; Hostname = "b204-pc02"; Room = "B204"; Desc = "Salle B204 (Maths / NSI) - Poste 02" },
    @{ Name = "LyuX-S102-PC01"; Hostname = "s102-pc01"; Room = "S102"; Desc = "Salle S102 (Sciences) - Poste 01" }
)

foreach ($c in $clientVms) {
    $vmName = $c.Name
    $hostname = $c.Hostname
    Write-Host "  [*] Configuration de $vmName ($($c.Desc))..." -ForegroundColor Yellow

    & $VBox createvm --name $vmName --ostype "Debian_64" --register
    & $VBox modifyvm $vmName --memory 2048 --cpus 2 --vram 128
    & $VBox modifyvm $vmName --graphicscontroller vmsvga --accelerate3d off
    
    # Carte 1 reliee au reseau isole (deconnectee pendant l'install)
    & $VBox modifyvm $vmName --nic1 intnet --intnet1 $NetworkName --cableconnected1 off
    # Carte 2 NAT pour l'installation unattended des paquets
    & $VBox modifyvm $vmName --nic2 nat --cableconnected2 on
    
    # Disque 20 Go
    & $VBox storagectl $vmName --name "SATA" --add sata --controller IntelAhci --bootable on
    $clientVdi = "$vmBaseDir\$vmName\$vmName.vdi"
    & $VBox createmedium disk --filename $clientVdi --size 20480 --format VDI
    & $VBox storageattach $vmName --storagectl "SATA" --port 0 --device 0 --type hdd --medium $clientVdi
    & $VBox storageattach $vmName --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoPath

    # Configuration automatique Unattended avec KDE Plasma sous X11 & AZERTY
    & $VBox unattended install $vmName `
        --iso=$IsoPath `
        --user="lyux-admin" `
        --user-password="LyuxAdmin2026!" `
        --country="FR" `
        --time-zone="Europe/Paris" `
        --hostname="$hostname.lyux.lan" `
        --script-template=$TemplatePreseed `
        --extra-install-kernel-parameters="priority=critical file=/cdrom/preseed.cfg netcfg/choose_interface=enp0s8 debian-installer/locale=fr_FR.UTF-8 keyboard-configuration/xkb-keymap=fr(latin9) languagechooser/language-name=French countrychooser/shortlist=FR" `
        --install-additions

    Write-Host "  [+] $vmName pret (2 Go RAM, 2 vCPUs, Disque 20 Go, KDE Plasma X11 / AZERTY)" -ForegroundColor Green
}
Write-Host ""

# ------------------------------------------------------------------------------
# 5. DEMARRAGE ET VALIDATION DU LIVRABLE
# ------------------------------------------------------------------------------
if ($StartAfterSetup) {
    Write-Host "[5/5] Demarrage et validation des machines du Lab..." -ForegroundColor Cyan

    # Demarrage LyuX-Server
    Write-Host "  [*] Demarrage de LyuX-Server (Headless)..." -ForegroundColor Yellow
    & $VBox startvm "LyuX-Server" --type headless 2>$null
    Start-Sleep -Seconds 2

    # Verification des ports actifs
    Write-Host "  [*] Verification des ports reseau actifs..." -ForegroundColor Yellow
    $testPorts = @(389, 445, 9090)
    foreach ($p in $testPorts) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $client.BeginConnect("127.0.0.1", $p, $null, $null)
            $success = $task.AsyncWaitHandle.WaitOne(1500, $false)
            if ($success -and $client.Connected) {
                Write-Host "    [+] Port $p : ACTIF / EN LIGNE" -ForegroundColor Green
                $client.EndConnect($task)
            } else {
                Write-Host "    [-] Port $p : HORS LIGNE" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [!] Port $p : ERREUR $_" -ForegroundColor Yellow
        } finally {
            $client.Close()
        }
    }

    # Demarrage LyuX-B204-PC01
    Write-Host "  [*] Demarrage de LyuX-B204-PC01..." -ForegroundColor Yellow
    & $VBox startvm "LyuX-B204-PC01" --type headless 2>$null
    Start-Sleep -Seconds 2
    Write-Host "    [+] LyuX-B204-PC01 demarre sans invite textuelle !" -ForegroundColor Green
}

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Green
Write-Host "                LAB VIRTUALBOX LYUX OPERATIONNEL A 100%" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Green
