# Vérifie si le script est exécuté en tant qu'administrateur
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ce script nécessite des privilèges administrateur. Relance avec élévation..." -ForegroundColor Red
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

Write-Host "Script exécuté avec les droits administrateur.`n" -ForegroundColor Green

Write-Host "Mise à jour de toutes les applications installées via WinGet..." -ForegroundColor Blue

# Met à jour tous les paquets disponibles
winget upgrade --all --accept-source-agreements --accept-package-agreements

Write-Host "`Mise à jour terminée." -ForegroundColor Green
pause
