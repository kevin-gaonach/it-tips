# https://github.com/kevin-gaonach/it-tips/
# Tiering AD 1.0
$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory

# Fonction de creation d'OU
function New-SecureOU {
    param (
        [string]$Name,
        [string]$Path
    )
    $ouPath = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$Name)" -SearchBase $Path -ErrorAction SilentlyContinue)) {
        
    $descriptionMap = @{
        "Computers" = "Conteneur dédié aux comptes d’ordinateurs"
        "Users" = "Conteneur dédié aux comptes d’utilisateurs"
        "Ressources" = "Conteneur dédié aux ressources partagées"
        "Servers" = "Conteneur dédié aux comptes de serveurs"
        "Groups" = "Conteneur dédié aux groupes de sécurité"
        "Services" = "Conteneur dédié aux comptes de services"
        "Admins" = "Conteneur dédié aux comptes à privilèges"
        "T0 - PRIVILEGED" = "Conteneur pour les comptes et services critiques (Tier 0)"
        "T1 - SECURED" = "Conteneur pour les services applicatifs et serveurs (Tier 1)"
        "T2 - MANAGED" = "Conteneur pour les comptes utilisateurs et postes de travail (Tier 2)"
    }
    $description = $descriptionMap[$Name]
    if ($description) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true -Description $description
    } else {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
    }
    }
    return $ouPath
}

#Recuperation des informations du domaine
$DN = (Get-ADDomain).DistinguishedName
$sites = Get-ADReplicationSite -Filter * | Select-Object Name

#Verification du nombre de sites AD
if ($sites -and $sites.Count -gt 1) {

    Add-Type -AssemblyName Microsoft.VisualBasic
    $MsgBox = "Veuillez confirmer la liste des sites AD :`n`n" + ($sites.Name -join "`n")
    $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgBox, "YesNo,Question", "Confirmation des sites")

    if ($result -eq "Yes") {
        
        # création d'une structure par site
        Write-Host "Action confirmée, création d'une structure par site" -ForegroundColor Green
                foreach ($tier in @("T0 - PRIVILEGED", "T1 - SECURED", "T2 - MANAGED")) {
                $tierPath = New-SecureOU -Name $tier -Path $DN
                    foreach ($site in $sites) {
                    $sitepath = New-SecureOU -Name $site.name -Path $tierPath
                    $ous = if ($tier -eq "T2 - MANAGED") { @("Computers", "Groups", "Admins", "Services", "Ressources", "Users") } else { @("Servers", "Groups", "Admins", "Services") }
                        foreach ($ou in $ous) {
                        New-SecureOU -Name $ou -Path $sitepath
                        }
                    }
                }
		Write-Host "Opération terminée" -ForegroundColor Green
	}    
else {
        Write-Host "Opération annulée" -ForegroundColor Red
    }}
else {
	Add-Type -AssemblyName Microsoft.VisualBasic
    $MsgBox = "Veuillez confirmer la création sans sites"
    $result = [Microsoft.VisualBasic.Interaction]::MsgBox($MsgBox, "YesNo,Question", "Confirmation des sites")

    if ($result -eq "Yes") {

    #création d'une structure simple sans site
    Write-Host "Action confirmée, création d'une structure simple sans site" -ForegroundColor Green

    foreach ($tier in @("T0 - PRIVILEGED", "T1 - SECURED", "T2 - MANAGED")) {
        $tierPath = New-SecureOU -Name $tier -Path $DN
        $ous = if ($tier -eq "T2 - MANAGED") { @("Computers", "Groups", "Admins", "Services", "Ressources", "Users") } else { @("Servers", "Groups", "Admins", "Services") }
        foreach ($ou in $ous) {
            New-SecureOU -Name $ou -Path $tierPath
        }
    }
	Write-Host "Opération terminée" -ForegroundColor Green
}else {
        Write-Host "Opération annulée" -ForegroundColor Red
    }
}
