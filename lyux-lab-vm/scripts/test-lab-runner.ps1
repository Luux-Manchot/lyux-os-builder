# ==============================================================================
# Script de verification et test d'etat du Virtual Lab LyuX (Feature 22)
# ==============================================================================
param (
    [string]$ServerHost = "127.0.0.1",
    [int]$TimeoutMs = 1500
)

$ErrorActionPreference = "Continue"

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "               VERIFICATION DU LAB VIRTUEL LYUX (OPERATION MANCHOT)" -ForegroundColor Yellow
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verification de VirtualBox / VBoxManage
Write-Host "[1/3] Verification de l'environnement VirtualBox..." -ForegroundColor Cyan
$VBoxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$VBoxFound = $false
$VBoxVersion = "N/A"

if (Test-Path $VBoxPath) {
    $VBoxFound = $true
} elseif (Get-Command "VBoxManage.exe" -ErrorAction SilentlyContinue) {
    $VBoxPath = (Get-Command "VBoxManage.exe").Source
    $VBoxFound = $true
}

if ($VBoxFound) {
    try {
        $VBoxVersion = (& $VBoxPath --version).Trim()
        Write-Host "  [+] VBoxManage detecte : $VBoxPath" -ForegroundColor Green
        Write-Host "  [+] Version VirtualBox  : $VBoxVersion" -ForegroundColor Green
        
        $vms = & $VBoxPath list vms
        $vmCount = ($vms | Where-Object { $_ -match '"' }).Count
        Write-Host "  [i] Nombre de VMs enregistrees : $vmCount" -ForegroundColor Gray
    } catch {
        Write-Host "  [!] Erreur lors de l'appel a VBoxManage : $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [-] VBoxManage non trouve au chemin par defaut." -ForegroundColor Yellow
}

Write-Host ""

# 2. Test de connectivite TCP des services du Lab
Write-Host "[2/3] Verification de la connectivite des services du Lab..." -ForegroundColor Cyan

function Test-PortStatus {
    param (
        [string]$TargetHost,
        [int]$Port,
        [string]$ServiceName,
        [int]$Timeout = 1500
    )

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connectTask = $tcpClient.BeginConnect($TargetHost, $Port, $null, $null)
    $success = $connectTask.AsyncWaitHandle.WaitOne($Timeout, $false)

    if ($success -and $tcpClient.Connected) {
        $tcpClient.EndConnect($connectTask)
        $tcpClient.Close()
        return [PSCustomObject]@{
            Service = $ServiceName
            Port    = $Port
            Status  = "ONLINE"
            Host    = $TargetHost
        }
    } else {
        $tcpClient.Close()
        return [PSCustomObject]@{
            Service = $ServiceName
            Port    = $Port
            Status  = "OFFLINE"
            Host    = $TargetHost
        }
    }
}

$services = @(
    @{ Name = "FastAPI Hub / API LyuX"; Port = 8000 },
    @{ Name = "Uptime Kuma Monitoring";  Port = 3001 },
    @{ Name = "Cockpit Web Admin";       Port = 9090 }
)

$results = @()
foreach ($s in $services) {
    $res = Test-PortStatus -TargetHost $ServerHost -Port $s.Port -ServiceName $s.Name -Timeout $TimeoutMs
    $results += $res
    if ($res.Status -eq "ONLINE") {
        Write-Host "  [+] $($res.Service) (Port $($res.Port)) : EN LIGNE" -ForegroundColor Green
    } else {
        Write-Host "  [-] $($res.Service) (Port $($res.Port)) : HORS LIGNE (Non demarre ou non redirige)" -ForegroundColor Yellow
    }
}

Write-Host ""

# 3. Synthese des tests
Write-Host "[3/3] Bilan du Lab Virtuel LyuX" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Gray
$results | Format-Table -AutoSize
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Gray

$onlineCount = ($results | Where-Object { $_.Status -eq "ONLINE" }).Count
$statusColor = if ($onlineCount -eq $results.Count) { "Green" } else { "Yellow" }
Write-Host "Services actifs : $onlineCount / $($results.Count)" -ForegroundColor $statusColor

Write-Host ""
Write-Host "[OK] Fin du diagnostic du Lab Virtuel." -ForegroundColor Green
