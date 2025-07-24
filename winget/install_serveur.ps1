# Vérifie si le script est exécuté en tant qu'administrateur
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ce script nécessite des privilèges administrateur. Relance avec élévation..." -ForegroundColor Red
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

Write-Host "Script exécuté avec les droits administrateur.`n" -ForegroundColor Green

$progressPreference = 'silentlyContinue'

# Vérifie si WinGet est déjà disponible
$wingetModuleInstalled = Get-Module -ListAvailable -Name "Microsoft.WinGet.Client"

if (!($wingetModuleInstalled)) {
    Write-Host "Installation du module WinGet PowerShell depuis PSGallery..." -ForegroundColor Blue
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Write-Host "Exécution de Repair-WinGetPackageManager pour initialisation..." -ForegroundColor Blue
    Repair-WinGetPackageManager
    Write-Host "Installation de WinGet terminée." -ForegroundColor Green
}

# Liste des applications à installer (IDs Winget)
$apps = @(
	# Gestion de fichiers
	"7zip.7zip",                        # 7-Zip : compression d'archives
	
	#️ Outils système et utilitaires
	"Notepad++.Notepad++"               # Notepad++ : éditeur de texte
)

$results = @()

foreach ($app in $apps) {
    Write-Host "`nInstallation de $app..." -ForegroundColor Blue
    $result = Install-WinGetPackage -Id $app  -Scope System -Source winget

    $results += [pscustomobject]@{
        Package = $result.Name
        Success = $result -ne $null
        Timestamp = Get-Date
    }
}

# Affichage du résumé
Write-Host "`nRésumé des installations :" -ForegroundColor Blue
$results | Format-Table -AutoSize
Write-Host "Installation terminée." -ForegroundColor Green
pause