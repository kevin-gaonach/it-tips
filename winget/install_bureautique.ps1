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
	# Outils PDF
	"PDFsam.PDFsam",                   # PDFsam : fusion et découpe de PDF
	"Adobe.Acrobat.Reader.64-bit",     # Adobe Reader : lecteur PDF
	
	# Navigateurs Web
	"Google.Chrome",                   # Google Chrome : navigateur web
	
	# Gestion de fichiers
	"7zip.7zip",                        # 7-Zip : compression d'archives
	"AntSoftware.AntRenamer",          # Ant Renamer : renommage de fichiers
	
	# Sécurité et sauvegarde
	"KeePassXCTeam.KeePassXC",         # KeePassXC : gestionnaire de mots de passe
	"Veeam.VeeamAgent",                # Veeam Agent : sauvegarde système
	
	# Multimédia et capture
	"VideoLAN.VLC",                    # VLC : lecteur multimédia
	"Greenshot.Greenshot",             # Greenshot : capture d'écran
	
	#️ Outils système et utilitaires
	"Notepad++.Notepad++",             # Notepad++ : éditeur de texte
	"WinDirStat.WinDirStat",           # WinDirStat : analyse d'espace disque
	"MartiCliment.UniGetUI",           # WingetUI : interface graphique pour winget
	"WinsiderSS.SystemInformer",       # System Informer : gestionnaire de tâches avancé
	"mRemoteNG.mRemoteNG"             # mRemoteNG : gestionnaire de connexions distantes
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