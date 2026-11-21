# ==============================================================================
# Script de deploiement de 2 Classes (2 PC par classe) avec KDE Plasma & AZERTY
# ==============================================================================

$VBox = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vmBaseDir = if ($env:USERPROFILE) { "$env:USERPROFILE\VirtualBox VMs" } else { "C:\VirtualBox VMs" }
if (-not (Test-Path $vmBaseDir)) { New-Item -ItemType Directory -Path $vmBaseDir -Force | Out-Null }

$candidateIsos = @(
    (Join-Path $PSScriptRoot "..\iso\debian-netinst.iso"),
    (Join-Path $PSScriptRoot "..\..\..\projects\lyux-lab-vm\iso\debian-netinst.iso"),
    (Join-Path (Get-Location) "projects\lyux-lab-vm\iso\debian-netinst.iso"),
    (Join-Path (Get-Location) "iso\debian-netinst.iso")
)
$IsoFile = ($candidateIsos | Where-Object { Test-Path $_ } | Select-Object -First 1)
if (-not $IsoFile) {
    $found = Get-ChildItem -Path (Resolve-Path "$PSScriptRoot\..\..") -Filter "*netinst.iso" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $IsoFile = $found.FullName }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Deploiement de 2 Classes (2 PC / classe) sous VirtualBox" -ForegroundColor Cyan
Write-Host "ISO utilisee : $IsoFile" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Configure-LyuXVM {
    param (
        [string]$VmName,
        [string]$Hostname,
        [string]$Description
    )

    Write-Host ""
    Write-Host "[*] Configuration de $VmName ($Description)..." -ForegroundColor Yellow

    # Eteindre et nettoyer l'ancienne VM
    $existing = & $VBox list vms
    if ($existing -match [regex]::Escape($VmName)) {
        & $VBox controlvm $VmName poweroff 2>$null
        Start-Sleep -Seconds 1
        & $VBox unregistervm $VmName --delete 2>$null
        Start-Sleep -Seconds 1
    }

    # 1. Creation de la VM
    & $VBox createvm --name $VmName --ostype "Debian_64" --register
    & $VBox modifyvm $VmName --memory 2048 --cpus 2 --vram 128
    & $VBox modifyvm $VmName --graphicscontroller vmsvga --accelerate3d off
    & $VBox modifyvm $VmName --nic1 nat --cableconnected1 on
    
    # 2. Disque VDI et Lecteur DVD
    & $VBox storagectl $VmName --name "SATA" --add sata --controller IntelAhci --bootable on
    $vdi = "$vmBaseDir\$VmName\$VmName.vdi"
    & $VBox createmedium disk --filename $vdi --size 20480 --format VDI
    & $VBox storageattach $VmName --storagectl "SATA" --port 0 --device 0 --type hdd --medium $vdi
    & $VBox storageattach $VmName --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoFile

    # 3. Installation Automatique Unattended avec KDE Plasma & Clavier AZERTY
    & $VBox unattended install $VmName `
        --iso=$IsoFile `
        --user="lyux-admin" `
        --user-password="LyuxAdmin2026!" `
        --country="FR" `
        --time-zone="Europe/Paris" `
        --hostname="$Hostname.lyux.lan" `
        --extra-install-kernel-parameters="auto=true priority=critical preseed/url=http://10.0.2.2:8000/preseed.cfg url=http://10.0.2.2:8000/preseed.cfg debian-installer/locale=fr_FR.UTF-8 keyboard-configuration/xkb-keymap=fr(latin9) languagechooser/language-name=French countrychooser/shortlist=FR tasksel:tasksel/first=multiselect standard, kde-desktop" `
        --install-additions

    Write-Host "  [+] $VmName configuree avec succes !" -ForegroundColor Green
}

# --- CLASSE 1 : Salle B204 (Maths / NSI - 1G1) ---
Configure-LyuXVM -VmName "LyuX-B204-PC1" -Hostname "b204-pc01" -Description "Classe 1 (B204) - Poste 1"
Configure-LyuXVM -VmName "LyuX-B204-PC2" -Hostname "b204-pc02" -Description "Classe 1 (B204) - Poste 2"

# --- CLASSE 2 : Salle S102 (Sciences / Physique - 1G2) ---
Configure-LyuXVM -VmName "LyuX-S102-PC1" -Hostname "s102-pc01" -Description "Classe 2 (S102) - Poste 1"
Configure-LyuXVM -VmName "LyuX-S102-PC2" -Hostname "s102-pc02" -Description "Classe 2 (S102) - Poste 2"

# --- VM VIERGE (Test Clé USB / Enrôlement de 0) ---
Write-Host ""
Write-Host "[*] Configuration de LyuX-PC-Vierge (Test Enrolement de 0)..." -ForegroundColor Yellow
$existingVierge = & $VBox list vms
if ($existingVierge -match "LyuX-PC-Vierge") {
    & $VBox controlvm "LyuX-PC-Vierge" poweroff 2>$null
    Start-Sleep -Seconds 1
    & $VBox unregistervm "LyuX-PC-Vierge" --delete 2>$null
}
& $VBox createvm --name "LyuX-PC-Vierge" --ostype "Debian_64" --register
& $VBox modifyvm "LyuX-PC-Vierge" --memory 2048 --cpus 2 --vram 128
& $VBox modifyvm "LyuX-PC-Vierge" --nic1 nat --cableconnected1 on
& $VBox storagectl "LyuX-PC-Vierge" --name "SATA" --add sata --controller IntelAhci --bootable on
$vdiVierge = "$vmBaseDir\LyuX-PC-Vierge\LyuX-PC-Vierge.vdi"
& $VBox createmedium disk --filename $vdiVierge --size 20480 --format VDI
& $VBox storageattach "LyuX-PC-Vierge" --storagectl "SATA" --port 0 --device 0 --type hdd --medium $vdiVierge
& $VBox storageattach "LyuX-PC-Vierge" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoFile
& $VBox modifyvm "LyuX-PC-Vierge" --boot1 dvd --boot2 disk --boot3 none
Write-Host "  [+] LyuX-PC-Vierge configuree !" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "LES 5 VMS SONT OPERATIONNELLES DANS VIRTUALBOX :" -ForegroundColor Green
Write-Host "• Classe 1 (B204) : LyuX-B204-PC1 et LyuX-B204-PC2" -ForegroundColor Green
Write-Host "• Classe 2 (S102) : LyuX-S102-PC1 et LyuX-S102-PC2" -ForegroundColor Green
Write-Host "• VM Vierge       : LyuX-PC-Vierge (Enrolement manuel de 0)" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
