# ==============================================================================
# Script PowerShell d'automatisation de creation des VMs LyuX sous VirtualBox
# ==============================================================================

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $VBoxManage)) {
    Write-Host "[ERREUR] VBoxManage.exe introuvable dans C:\Program Files\Oracle\VirtualBox\" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Initialisation du Lab Multi-VM LyuX sous VirtualBox" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$NetworkName = "LyuX-Lab-Net"

function New-LyuXVirtualMachine {
    param (
        [string]$Name,
        [int]$Ram,
        [int]$Cpus,
        [string]$Description
    )

    Write-Host ""
    Write-Host "[*] Configuration de la VM : $Name ($Description)..." -ForegroundColor Yellow

    # Verification de l'existence de la VM
    $vmList = & $VBoxManage list vms
    if ($vmList -match [regex]::Escape($Name)) {
        Write-Host "  [-] La VM '$Name' existe deja dans VirtualBox." -ForegroundColor Gray
        return
    }

    # 1. Creation et enregistrement
    & $VBoxManage createvm --name $Name --ostype "Debian_64" --register
    
    # 2. Ressources CPU / RAM / Graphique
    & $VBoxManage modifyvm $Name --memory $Ram --cpus $Cpus --vram 64
    & $VBoxManage modifyvm $Name --graphicscontroller vmsvga --accelerate3d off
    
    # 3. Carte Réseau 1 : Reseau Interne LyuX
    & $VBoxManage modifyvm $Name --nic1 intnet --intnet1 $NetworkName --cableconnected1 on
    
    # 4. Carte Réseau 2 : NAT (Acces Internet pour installation)
    & $VBoxManage modifyvm $Name --nic2 nat --cableconnected2 on

    # 5. Ordre de boot
    & $VBoxManage modifyvm $Name --boot1 net --boot2 disk --boot3 dvd

    Write-Host "  [+] VM '$Name' configuree avec succes !" -ForegroundColor Green
}

# Creation des 3 machines virtuelles
New-LyuXVirtualMachine -Name "LyuX-Server" -Ram 4096 -Cpus 2 -Description "Serveur Central"
New-LyuXVirtualMachine -Name "LyuX-Client-Prof" -Ram 3072 -Cpus 2 -Description "Poste Enseignant"
New-LyuXVirtualMachine -Name "LyuX-Client-Eleve" -Ram 2048 -Cpus 2 -Description "Poste Eleve"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Les 3 VMs sont maintenant creees dans Oracle VirtualBox !" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
