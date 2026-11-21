# ==============================================================================
# LyuX - Lanceur de VM Interactive avec Passerelle Serveur
# ==============================================================================
param (
    [string]$VmName = "LyuX-PC-Vierge"
)

$VBox = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $VBox)) {
    Write-Host "[!] VirtualBox n'est pas installe dans le chemin standard : $VBox" -ForegroundColor Red
    exit 1
}

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "         LYUX - DEMARRAGE RAPIDE VM ET ASSISTANT DE CONFIGURATION" -ForegroundColor Yellow
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verification de l'existence de la VM
$registeredVms = & $VBox "list", "vms"
if ($registeredVms -notmatch [regex]::Escape($VmName)) {
    Write-Host "[*] Enregistrement de la machine $VmName..." -ForegroundColor Yellow
    & $VBox "createvm", "--name", $VmName, "--ostype", "Debian_64", "--register" 2>$null
    & $VBox "modifyvm", $VmName, "--memory", "2048", "--cpus", "2", "--vram", "128", "--graphicscontroller", "vboxvga", "--boot1", "dvd", "--boot2", "disk", "--nic1", "nat"
}

# 2. Demarrage de la VM
Write-Host "[*] Lancement de la machine virtuelle $VmName dans VirtualBox..." -ForegroundColor Green
& $VBox "startvm", $VmName, "--type", "gui"

Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  [OK] Machine virtuelle lancee dans VirtualBox !" -ForegroundColor Green
Write-Host "  [INFO] Adresse du serveur LyuX vue depuis la VM : http://10.0.2.2:8000" -ForegroundColor White
Write-Host "===============================================================================" -ForegroundColor Cyan
