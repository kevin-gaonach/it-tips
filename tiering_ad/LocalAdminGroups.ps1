<#
.SYNOPSIS
Crée et maintient automatiquement les groupes Active Directory "LocalAdmins" pour chaque ordinateur 
en fonction du modèle de tiering (T0/T1/T2).

.DESCRIPTION
Ce script PowerShell gère automatiquement les groupes AD de type "LocalAdmins-<NomMachine>" 
pour chaque ordinateur du domaine. 

Il prend en compte la structure de tiering Active Directory (Tier 0 / Tier 1 / Tier 2) 
et supporte aussi bien les environnements mono-site que multi-site.

Le script :
- Vérifie la présence du module ActiveDirectory.
- Détecte les sites Active Directory si présents.
- Crée les groupes dans les OU "Groups" correspondantes (par site et par tier).
- Nettoie automatiquement les groupes "LocalAdmins-*" orphelins dont l’ordinateur n’existe plus dans l’OU.
- Évite la duplication : si le groupe existe déjà et que l’ordinateur est présent, aucune action n’est effectuée.

.OUTPUTS
Le script affiche dans la console et écrit dans un fichier de log :
- Les groupes créés.
- Les groupes déjà existants.
- Les groupes supprimés car associés à des ordinateurs inexistants.

.NOTES
Auteur     : Kevin Gaonach
Site Web   : https://github.com/kevin-gaonach/it-tips/
Version    : 1.0
Date       : 2025-08-28

.EXAMPLE
.\LocalAdminGroups.ps1

Lance le script, nettoie les groupes orphelins et crée/maintient les groupes "LocalAdmins-<NomMachine>" 
dans les OU de groupes correspondantes pour chaque Tier (T0, T1, T2).
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

# Import du module Active Directory (si nécessaire)
Import-Module ActiveDirectory

# Définir le préfixe du groupe administrateur
$prefix = "LocalAdmins-"

# Récupérer tous les objets ordinateurs avec leur nom et leur système d'exploitation
$computers = Get-ADComputer -Filter * -Property Name,OperatingSystem,DistinguishedName

function Create-LocalAdminGroup {
    param (
        [string]$ComputerName,
        [string]$OUPath
    )
    
    $groupName = ($prefix + $ComputerName)
    
    # Vérifie si le groupe existe
    $existingGroup = Get-ADGroup -Filter { Name -eq $groupName } -SearchBase $OUPath -ErrorAction SilentlyContinue

    if (-not $existingGroup) {
        Write-Log "Création du groupe $groupName dans $OUPath"
        
        New-ADGroup -Name $groupName `
                    -SamAccountName $groupName `
                    -GroupCategory Security `
                    -GroupScope DomainLocal `
                    -Path $OUPath `
                    -Description "Administrateurs locaux de $ComputerName" `
                    -ErrorAction Stop
    } else {
        Write-Log "Le groupe $groupName existe déjà. Aucune action."
    }
}

function Clean-LocalAdminGroups {
    param (
        [string]$OUPath
    )

    # Récupère tous les groupes LocalAdmins dans l'OU
    $filter = "Name -like '$prefix*'"
    $groups = Get-ADGroup -Filter $filter -SearchBase $OUPath -ErrorAction SilentlyContinue

    foreach ($group in $groups) {
        if ($group.Name -match "^$prefix(.+)$") {
            $computerName = $Matches[1]

            # Vérifie si l'objet ordinateur existe dans l'OU Tier associée
            $computer = Get-ADComputer -Filter "Name -eq '$computerName'" -SearchBase $OUPath -ErrorAction SilentlyContinue

            if (-not $computer) {
                Write-Log "Ordinateur '$computerName' introuvable dans $OUPath. Suppression du groupe '$($group.Name)'."
                Remove-ADGroup -Identity $group.DistinguishedName -Confirm:$false -ErrorAction Stop
            } else {
                Write-Log "Ordinateur '$computerName' existe toujours. Aucun changement pour '$($group.Name)'."
            }
        }
    }
}


# Récupération du DN du domaine
$DN = (Get-ADDomain).DistinguishedName
$sites = Get-ADReplicationSite -Filter *

if ($sites.Count -gt 1) {
    Write-Log "Mode multi-site détecté : $($sites.Count) sites trouvés."

    foreach ($site in $sites) {
        Write-Log "`n--- Traitement du site : $($site.Name) ---"

        # Initialiser les listes par site
        $tier0 = @()
        $tier1 = @()
        $tier2 = @()

        # Récupérer les ordinateurs associés au site
        $siteComputers = Get-ADComputer -Filter * -Property Name,DistinguishedName | Where-Object { $_.DistinguishedName -like "*OU=$($site.Name)*" }

        foreach ($computer in $siteComputers) {
            if ($computer.DistinguishedName -like "*OU=T0 - PRIVILEGED*") {
                $tier0 += $computer
            } elseif ($computer.DistinguishedName -like "*OU=T1 - SECURED*") {
                $tier1 += $computer
            } elseif ($computer.DistinguishedName -like "*OU=T2 - MANAGED*") {
                $tier2 += $computer
            }
        }

        # Construire les OU Groups spécifiques au site
		$tier0OU = "OU=$($site.Name),OU=T0 - PRIVILEGED,$DN"
		$tier1OU = "OU=$($site.Name),OU=T1 - SECURED,$DN"
		$tier2OU = "OU=$($site.Name),OU=T2 - MANAGED,$DN"
		
        $tier0OUGroups = "OU=Groups,$tier0OU"
        $tier1OUGroups = "OU=Groups,$tier1OU"
        $tier2OUGroups = "OU=Groups,$tier2OU"
		

		# Nettoyage des groupes orphelins
		Clean-LocalAdminGroups -OUPath $tier0OU
		Clean-LocalAdminGroups -OUPath $tier1OU
		Clean-LocalAdminGroups -OUPath $tier2OU 
		
        # Création des groupes
        foreach ($server in $tier0) {
            Create-LocalAdminGroup -ComputerName $server.Name -OUPath $tier0OUGroups
        }
        foreach ($server in $tier1) {
            Create-LocalAdminGroup -ComputerName $server.Name -OUPath $tier1OUGroups
        }
        foreach ($client in $tier2) {
            Create-LocalAdminGroup -ComputerName $client.Name -OUPath $tier2OUGroups
        }
    }
}
else {
    Write-Log "Mode mono-site détecté"

    # Initialiser trois listes
    $tier0 = @()
    $tier1 = @()
    $tier2 = @()

    # Parcourir chaque ordinateur et trier selon l'OU
    foreach ($computer in $computers) {
        if ($computer.DistinguishedName -like "*OU=T0 - PRIVILEGED*") {
            $tier0 += $computer
        } elseif ($computer.DistinguishedName -like "*OU=T1 - SECURED*") {
            $tier1 += $computer
        } elseif ($computer.DistinguishedName -like "*OU=T2 - MANAGED*") {
            $tier2 += $computer
        }
    }

    # Chemins des OU
	$tier0OU = "OU=T0 - PRIVILEGED,$DN"
	$tier1OU = "OU=T1 - SECURED,$DN"
	$tier2OU = "OU=T2 - MANAGED,$DN"
	
    $tier0OUGroups = "OU=Groups,$tier0OU"
    $tier1OUGroups = "OU=Groups,$tier1OU"
    $tier2OUGroups = "OU=Groups,$tier2OU"
	
	# Nettoyage des groupes orphelins
	Clean-LocalAdminGroups -OUPath $tier0OU 
	Clean-LocalAdminGroups -OUPath $tier1OU 
	Clean-LocalAdminGroups -OUPath $tier2OU 
	
    # Création des groupes
    foreach ($server in $tier0) {
        Create-LocalAdminGroup -ComputerName $server.Name -OUPath $tier0OUGroups
    }
    foreach ($server in $tier1) {
        Create-LocalAdminGroup -ComputerName $server.Name -OUPath $tier1OUGroups
    }
    foreach ($client in $tier2) {
        Create-LocalAdminGroup -ComputerName $client.Name -OUPath $tier2OUGroups
    }
}
