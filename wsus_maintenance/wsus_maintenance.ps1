# https://github.com/kevin-gaonach/it-tips/
# WSUS Maintenance 1.0
$ErrorActionPreference = "Stop"

# Génère un nom de log unique avec horodatage
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath   = Join-Path -Path $PSScriptRoot -ChildPath "$timestamp.txt"

# Fonction de journalisation
function Log {
    param([string]$message)
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$now`t$message" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

try {
    Log "Début du script WSUS"

    # Vérifie la disponibilité du module WSUS
    if (-not (Get-Command Get-WsusUpdate -ErrorAction SilentlyContinue)) {
        Log "Le module WSUS n'est pas disponible. Exécution annulée."
        throw "Commande Get-WsusUpdate non trouvée. Le script doit être exécuté sur un serveur WSUS."
    }

    # Décline les mises à jour remplacées
    Log "Détection des mises à jour remplacées à décliner..."
    $declinedUpdates = Get-WsusUpdate -Classification All -Status Any -Approval AnyExceptDeclined |
        Where-Object {
            $_.Update.GetRelatedUpdates(
                [Microsoft.UpdateServices.Administration.UpdateRelationship]::UpdatesThatSupersedeThisUpdate
            ).Count -gt 0
        }

    Log "Nombre de mises à jour à décliner : $($declinedUpdates.Count)"
    $declinedUpdates | ForEach-Object {
        Log "Déclinée : $($_.Update.Title)"
        Deny-WsusUpdate -Update $_
    }

    # Approuve les mises à jour valides non remplacées
    Log "Détection des mises à jour non remplacées à approuver..."
    $unapprovedUpdates = Get-WsusUpdate -Classification All -Status Any -Approval Unapproved |
        Where-Object {
            $_.Update.GetRelatedUpdates(
                [Microsoft.UpdateServices.Administration.UpdateRelationship]::UpdatesThatSupersedeThisUpdate
            ).Count -eq 0
        }

    Log "Nombre de mises à jour à approuver : $($unapprovedUpdates.Count)"
    $unapprovedUpdates | ForEach-Object {
        Log "Approuvée : $($_.Update.Title)"
        Approve-WsusUpdate -Update $_ -Action Install -TargetGroupName "PROD"
    }

    # Nettoyage complet du serveur WSUS
    Log "Nettoyage du serveur WSUS..."
    $clean = Invoke-WsusServerCleanup -CleanupObsoleteUpdates -CleanupUnneededContentFiles
    Log $clean
    Log "Nettoyage terminé."

    Log "Fin du script WSUS"
} catch {
    Log "Erreur : $($_.Exception.Message)"
    throw
}
