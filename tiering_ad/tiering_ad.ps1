<#
.SYNOPSIS
Cree automatiquement une structure d’unites d’organisation (OU) selon le modele de tiering Active Directory.

.DESCRIPTION
Ce script PowerShell permet de generer une hierarchie d’OUs basee sur le modele Tier 0 / Tier 1 / Tier 2.
Il detecte les sites Active Directory et cree automatiquement les conteneurs appropries pour chaque niveau de securite.

Le script :
- Verifie la presence du module ActiveDirectory.
- Genere un fichier de log dans le dossier du script.
- Utilise des boîtes de dialogue pour confirmer l'action.
- Cree des OUs protegees contre la suppression accidentelle avec des descriptions adaptees.

.OUTPUTS
Un fichier log est genere a chaque execution dans le dossier du script avec un nom base sur la date et l’heure.

.NOTES
Auteur     : Kevin Gaonach  
Site Web   : https://github.com/kevin-gaonach/it-tips/  
Version    : 1.0  
Date       : 2025-07-25

.EXAMPLE
.\Tiering-AD.ps1

Lance le script et cree la structure tiering en fonction des sites AD detectes.

#>

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

# Fonction de creation d'une nouvelle OU
function New-SecureOU {
    param (
        [string]$Name,
        [string]$Path
    )
    $ouPath = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$Name)" -SearchBase $Path -ErrorAction SilentlyContinue)) {
        $descriptionMap = @{
            "Computers"       = "Conteneur dedie aux comptes d’ordinateurs"
            "Users"           = "Conteneur dedie aux comptes d’utilisateurs"
            "Ressources"      = "Conteneur dedie aux ressources partagees"
            "Servers"         = "Conteneur dedie aux comptes de serveurs"
            "Groups"          = "Conteneur dedie aux groupes de securite"
            "Services"        = "Conteneur dedie aux comptes de services"
            "Admins"          = "Conteneur dedie aux comptes a privileges"
            "T0 - PRIVILEGED" = "Conteneur pour les comptes et services critiques (Tier 0)"
            "T1 - SECURED"    = "Conteneur pour les services applicatifs et serveurs (Tier 1)"
            "T2 - MANAGED"    = "Conteneur pour les comptes utilisateurs et postes de travail (Tier 2)"
        }

        $description = $descriptionMap[$Name]
        $logMsg = "Creation de l'OU '$Name' sous '$Path'"

            Write-Log $logMsg
            if ($description) {
                New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true -Description $description
            } else {
                New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
            }

    } else {
        Write-Log "OU '$Name' existe deja sous '$Path'"
    }
    return $ouPath
}

try {
    Write-Log "Debut du script Tiering AD"

    # Verifie la disponibilite du module Active Directory
    if (-not (Get-Command Get-ADDomain -ErrorAction SilentlyContinue)) {
        Write-Log "Le module Active Directory n'est pas disponible. Execution annulee."
        throw "Commande Get-ADDomain non trouvee. Le script doit être execute sur un serveur Active Directory."
    }

    # Recuperation du DN et des sites
    $DN = (Get-ADDomain).DistinguishedName
    $sites = Get-ADReplicationSite -Filter * | Select-Object Name

    if ($sites -and $sites.Count -gt 1) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $MsgBox = "Veuillez confirmer la liste des sites AD :`n`n" + ($sites.Name -join "`n")
        $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgBox, "YesNo,Question", "Confirmation des sites")

        if ($result -eq "Yes") {
            Write-Log "Action confirmee, creation d'une structure par site"

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

            Write-Log "Structure AD par site terminee"
        } else {
            Write-Log "Operation annulee par l'utilisateur"
        }
    } else {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $MsgBox = "Un seul site detecte. Confirmer la creation d'une structure simple sans site ?"
        $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgBox, "YesNo,Question", "Confirmation")

        if ($result -eq "Yes") {
            Write-Log "Action confirmee, creation d'une structure simple sans site"

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

            Write-Log "Structure AD simple terminee"
        } else {
            Write-Log "Operation annulee par l'utilisateur"
        }
    }
} catch {
    Write-Log "Erreur : $($_.Exception.Message)"
    throw
}
