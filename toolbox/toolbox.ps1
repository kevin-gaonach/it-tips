<#
.SYNOPSIS
Installe automatiquement une liste d'outils essentiels pour l'administration Windows via WinGet.

.DESCRIPTION
Ce script PowerShell installe une selection d'applications couramment utilisees pour l'administration systeme 
et la maintenance de postes Windows. Il verifie si le module PowerShell pour WinGet est disponible, 
et l'installe si necessaire. Les applications sont ensuite installees en utilisant leurs identifiants WinGet.

.NOTES
Auteur     : Kevin Gaonach  
Site Web   : https://github.com/kevin-gaonach/it-tips/  
Version    : 1.0  
Date       : 2025-07-27

.EXAMPLE
.\toolbox.ps1

Lance le script et installe automatiquement les applications definies.
#>

# Creation du dossier Logs
$logsFolder = Join-Path -Path $PSScriptRoot -ChildPath "Logs"

# Verifie et cree le dossier Logs si necessaire
if (-not (Test-Path -Path $logsFolder)) {
    New-Item -Path $logsFolder -ItemType Directory | Out-Null
}

# Definition du fichier de log dans Logs
$logFileName = "$($MyInvocation.MyCommand.Name -replace '\.ps1$','')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logPath = Join-Path -Path $logsFolder -ChildPath $logFileName

# Fonction de journalisation
function Write-Log {
    param ([string]$Message)
    $timestamp  = Get-Date -Format 'dd/MM/yyyy-HH:mm:ss'
    $entry = "$timestamp - $Message"
    Write-Host $entry
    Add-Content -Path $logPath -Value $entry
}

function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (Test-IsAdmin) {

Write-Log "Demarrage du script."

# Verifie si le module WinGet est disponible
$wingetModuleInstalled = Get-Module -ListAvailable -Name "Microsoft.WinGet.Client"

if (!($wingetModuleInstalled)) {
    Write-Log "Module Microsoft.WinGet.Client non trouve. Installation en cours..."
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Write-Log "Module installe avec succes."

    Write-Log "Execution de Repair-WinGetPackageManager..."
    Repair-WinGetPackageManager
    Write-Log "Reparation terminee."
} else {
    Write-Log "Module Microsoft.WinGet.Client deja installe."
}

# Liste des applications a installer via WinGet
$apps = @(
    @{ Id = "mRemoteNG.mRemoteNG";           Name = "mRemoteNG" },
    @{ Id = "KeePassXCTeam.KeePassXC";       Name = "KeePassXC" },
    @{ Id = "MartiCliment.UniGetUI";         Name = "UniGetUI" },
    @{ Id = "WinsiderSS.SystemInformer";     Name = "System Informer" },
    @{ Id = "Famatech.AdvancedIPScanner";    Name = "Advanced IP Scanner" },
    @{ Id = "WinDirStat.WinDirStat";         Name = "WinDirStat" },
    @{ Id = "Greenshot.Greenshot";           Name = "Greenshot" },
    @{ Id = "Notepad++.Notepad++";           Name = "Notepad++" },
    @{ Id = "Robware.RVTools";               Name = "RVTools" },
    @{ Id = "Microsoft.Sysinternals.Suite";  Name = "Sysinternals Suite" }
)

$results = @()

foreach ($app in $apps) {
    Write-Log "Installation de $($app.Name)..."
    
    try {
        $result = Install-WinGetPackage -Id $app.Id -Scope System -Source winget -ErrorAction Stop

        $results += [pscustomobject]@{
            Package   = $app.Name
            Success   = $true
            Timestamp = Get-Date
        }

        Write-Log "Installation reussie de $($app.Name)."
    } catch {
        $results += [pscustomobject]@{
            Package   = $app.Name
            Success   = $false
            Timestamp = Get-Date
        }

        Write-Log "echec de l'installation de $($app.Name) : $($_.Exception.Message)"
    }
}

# Affichage du resume
Write-Log "Rapport :"
$results | ForEach-Object {
    $status = if ($_.Success) { "Succes" } else { "echec" }
    Write-Log "$($_.Package) : $status"
}

Write-Log "Script termine."

} else {
	Write-Host " Ce script doit etre execute avec des droits administrateur." -ForegroundColor Red
}