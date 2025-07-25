<#
.SYNOPSIS


.DESCRIPTION


.PARAMETER 


.OUTPUTS


.NOTES
Auteur     : Kevin Gaonach  
Site Web   : https://github.com/kevin-gaonach/it-tips/  
Version    : 1.0  
Date       : 2025-07-25  
Compatibilite : 

.REQUIREMENTS


.EXAMPLE
.\<scriptname>.ps1


#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Nom du groupe cible WSUS (ex: 'Serveurs')")]
    [string]$TargetGroup
)

$ErrorActionPreference = "Stop"

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