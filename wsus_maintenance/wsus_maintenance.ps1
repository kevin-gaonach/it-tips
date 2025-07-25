<#
.SYNOPSIS
Automatise la maintenance d’un serveur WSUS : approbation, declin et nettoyage des mises a jour.

.DESCRIPTION
Ce script PowerShell execute une serie d'operations de maintenance sur un serveur WSUS :
- Decliner automatiquement les mises a jour obsoletes ou remplacees.
- Approuver les mises a jour valides non remplacees pour un groupe cible WSUS specifique.
- Nettoyer le serveur (mises a jour obsoletes, fichiers non utilises, etc.).
- Generer un journal d'execution detaille avec horodatage.

.PARAMETER TargetGroup
Nom du groupe cible WSUS (ex: "Serveurs", "Postes", etc.) pour lequel les mises a jour seront approuvees.

.OUTPUTS
Un fichier de log est genere dans le repertoire du script, avec un nom base sur la date et l’heure.

.NOTES
Auteur     : Kevin Gaonach  
Site Web   : https://github.com/kevin-gaonach/it-tips/  
Version    : 1.0  
Date       : 2025-07-25  
Compatibilite : PowerShell 5.1, module WSUS requis

.REQUIREMENTS
- Être execute sur un serveur WSUS avec les droits administrateur.
- Le module WSUS PowerShell doit être disponible (Get-WsusUpdate, Approve-WsusUpdate, etc.).

.EXAMPLE
.\Maintenance-WSUS.ps1 -TargetGroup "Serveurs"

Lance la maintenance WSUS et applique les actions d’approbation/declin/nettoyage pour le groupe "Serveurs".
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

try {
    Write-Log "Debut du script WSUS"

    
    # Verifie la disponibilite du module WSUS
    if (-not (Get-Command Get-WsusUpdate -ErrorAction SilentlyContinue)) {
        Write-Log "Le module WSUS n'est pas disponible. Execution annulee."
        throw "Commande Get-WsusUpdate non trouvee. Le script doit être execute sur un serveur WSUS."
    }

    # Decline les mises a jour remplacees
    Write-Log "Detection des mises a jour remplacees a decliner..."
    $declinedUpdates = Get-WsusUpdate -Classification All -Status Any -Approval AnyExceptDeclined |
        Where-Object {
            $_.Update.GetRelatedUpdates(
                [Microsoft.UpdateServices.Administration.UpdateRelationship]::UpdatesThatSupersedeThisUpdate
            ).Count -gt 0
        }

    Write-Log "Nombre de mises a jour a decliner : $($declinedUpdates.Count)"
    $declinedUpdates | ForEach-Object {
        Write-Log "Declinee : $($_.Update.Title)"
        Deny-WsusUpdate -Update $_
    }

    # Approuve les mises a jour valides non remplacees
    Write-Log "Detection des mises a jour non remplacees a approuver..."
    $unapprovedUpdates = Get-WsusUpdate -Classification All -Status Any -Approval Unapproved |
        Where-Object {
            $_.Update.GetRelatedUpdates(
                [Microsoft.UpdateServices.Administration.UpdateRelationship]::UpdatesThatSupersedeThisUpdate
            ).Count -eq 0
        }

    Write-Log "Nombre de mises a jour a approuver : $($unapprovedUpdates.Count)"
    $unapprovedUpdates | ForEach-Object {
        Write-Log "Approuvee : $($_.Update.Title)"
        Approve-WsusUpdate -Update $_ -Action Install -TargetGroupName $TargetGroup
    }

    # Nettoyage complet du serveur WSUS
    Write-Log "Nettoyage du serveur WSUS..."
    $clean = Invoke-WsusServerCleanup -CleanupObsoleteUpdates -CleanupUnneededContentFiles
    Write-Log $clean
    Write-Log "Nettoyage termine."

    Write-Log "Fin du script WSUS"
} catch {
    Write-Log "Erreur : $($_.Exception.Message)"
    throw
}
