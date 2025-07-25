# https://github.com/kevin-gaonach/it-tips/
# Tiering AD

$ErrorActionPreference = "Stop"

# Définition du fichier de log
$logPath = "$PSScriptRoot\$($MyInvocation.MyCommand.Name -replace '\.ps1$','')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonction de journalisation
function Write-Log {
    param ([string]$Message)
    $timestamp  = Get-Date -Format 'dd/MM/yyyy-HH:mm:ss'
    $entry = "$timestamp - $Message"
    Write-Host $entry
    Add-Content -Path $logPath -Value $entry
}

# Fonction de création d'une nouvelle OU
function New-SecureOU {
    param (
        [string]$Name,
        [string]$Path
    )
    $ouPath = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$Name)" -SearchBase $Path -ErrorAction SilentlyContinue)) {
        $descriptionMap = @{
            "Computers"       = "Conteneur dédié aux comptes d’ordinateurs"
            "Users"           = "Conteneur dédié aux comptes d’utilisateurs"
            "Ressources"      = "Conteneur dédié aux ressources partagées"
            "Servers"         = "Conteneur dédié aux comptes de serveurs"
            "Groups"          = "Conteneur dédié aux groupes de sécurité"
            "Services"        = "Conteneur dédié aux comptes de services"
            "Admins"          = "Conteneur dédié aux comptes à privilèges"
            "T0 - PRIVILEGED" = "Conteneur pour les comptes et services critiques (Tier 0)"
            "T1 - SECURED"    = "Conteneur pour les services applicatifs et serveurs (Tier 1)"
            "T2 - MANAGED"    = "Conteneur pour les comptes utilisateurs et postes de travail (Tier 2)"
        }

        $description = $descriptionMap[$Name]
        $logMsg = "Création de l'OU '$Name' sous '$Path'"

            Write-Log $logMsg
            if ($description) {
                New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true -Description $description
            } else {
                New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
            }

    } else {
        Write-Log "OU '$Name' existe déjà sous '$Path'"
    }
    return $ouPath
}

try {
    Write-Log "Début du script Tiering AD"

    # Vérifie la disponibilité du module Active Directory
    if (-not (Get-Command Get-ADDomain -ErrorAction SilentlyContinue)) {
        Write-Log "Le module Active Directory n'est pas disponible. Exécution annulée."
        throw "Commande Get-ADDomain non trouvée. Le script doit être exécuté sur un serveur Active Directory."
    }

    # Récupération du DN et des sites
    $DN = (Get-ADDomain).DistinguishedName
    $sites = Get-ADReplicationSite -Filter * | Select-Object Name

    if ($sites -and $sites.Count -gt 1) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $MsgBox = "Veuillez confirmer la liste des sites AD :`n`n" + ($sites.Name -join "`n")
        $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgBox, "YesNo,Question", "Confirmation des sites")

        if ($result -eq "Yes") {
            Write-Log "Action confirmée, création d'une structure par site"

            # T0 - PRIVILEGED
            $t0Path = New-SecureOU -Name "T0 - PRIVILEGED" -Path $DN
            foreach ($ou in @("Servers", "Groups", "Admins", "Services")) {
                New-SecureOU -Name $ou -Path $t0Path
            }

            # T1 - SECURED
            $t1Path = New-SecureOU -Name "T1 - SECURED" -Path $DN
            foreach ($site in $sites) {
                $sitePath = New-SecureOU -Name $site.Name -Path $t1Path
                foreach ($ou in @("Servers", "Groups", "Admins", "Services")) {
                    New-SecureOU -Name $ou -Path $sitePath
                }
            }

            # T2 - MANAGED
            $t2Path = New-SecureOU -Name "T2 - MANAGED" -Path $DN
            foreach ($site in $sites) {
                $sitePath = New-SecureOU -Name $site.Name -Path $t2Path
                foreach ($ou in @("Computers", "Groups", "Admins", "Services", "Ressources", "Users")) {
                    New-SecureOU -Name $ou -Path $sitePath
                }
            }

            Write-Log "Structure AD par site terminée"
        } else {
            Write-Log "Opération annulée par l'utilisateur"
        }
    } else {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $MsgBox = "Un seul site détecté. Confirmer la création d'une structure simple sans site ?"
        $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgBox, "YesNo,Question", "Confirmation")

        if ($result -eq "Yes") {
            Write-Log "Action confirmée, création d'une structure simple sans site"

            foreach ($tier in @("T0 - PRIVILEGED", "T1 - SECURED", "T2 - MANAGED")) {
                $tierPath = New-SecureOU -Name $tier -Path $DN
                $ous = if ($tier -eq "T2 - MANAGED") {
                    @("Computers", "Groups", "Admins", "Services", "Ressources", "Users")
                } else {
                    @("Servers", "Groups", "Admins", "Services")
                }
                foreach ($ou in $ous) {
                    New-SecureOU -Name $ou -Path $tierPath
                }
            }

            Write-Log "Structure AD simple terminée"
        } else {
            Write-Log "Opération annulée par l'utilisateur"
        }
    }
} catch {
    Write-Log "Erreur : $($_.Exception.Message)"
    throw
}
