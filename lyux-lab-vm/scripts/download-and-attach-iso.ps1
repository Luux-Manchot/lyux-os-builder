# ==============================================================================
# Script de telechargement et attachement de l'ISO Debian 13 aux VMs
# ==============================================================================

$VBox = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$IsoDir = Join-Path $PSScriptRoot "..\iso"
$IsoPath = "$IsoDir\debian-netinst.iso"
$IsoUrl = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.8.0-amd64-netinst.iso"

# 1. Creation du dossier ISO
if (-not (Test-Path $IsoDir)) {
    New-Item -ItemType Directory -Path $IsoDir | Out-Null
}

# 2. Telechargement si non existant
if (-not (Test-Path $IsoPath)) {
    Write-Host "[*] Telechargement de l'ISO Debian 13 Netinst (~600 Mo)..." -ForegroundColor Yellow
    Write-Host "    Source : $IsoUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $IsoUrl -OutFile $IsoPath
    Write-Host "[+] Telechargement termine !" -ForegroundColor Green
} else {
    Write-Host "[i] L'ISO Debian 13 est deja presente : $IsoPath" -ForegroundColor Green
}

# 3. Eteindre la VM si en cours
$running = & $VBox list runningvms
if ($running -match "LyuX-Server") {
    Write-Host "[*] Extinction de la VM LyuX-Server pour inserer le DVD..." -ForegroundColor Yellow
    & $VBox controlvm "LyuX-Server" poweroff
    Start-Sleep -Seconds 2
}

# 4. Attacher l'ISO
Write-Host "[*] Insertion de l'ISO dans le lecteur DVD des 3 VMs..." -ForegroundColor Cyan
& $VBox storageattach "LyuX-Server" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoPath
& $VBox storageattach "LyuX-Client-Prof" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoPath
& $VBox storageattach "LyuX-Client-Eleve" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $IsoPath

Write-Host "[+] L'ISO Debian 13 est prete et inseree dans vos 3 VMs !" -ForegroundColor Green
