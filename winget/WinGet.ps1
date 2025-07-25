<#
.SYNOPSIS
Interface graphique PowerShell pour l'installation et la mise à jour d'applications via WinGet.

.DESCRIPTION
Ce script vérifie si les droits administrateur sont présents, installe le module WinGet si nécessaire,
et affiche une interface graphique (GUI) permettant de sélectionner et d’installer des applications courantes 
par catégories (Développement, Bureautique, Admins, Gaming, etc.) en utilisant WinGet. 

Deux boutons permettent :
- d'installer les applications sélectionnées
- de mettre à jour toutes les applications WinGet installées

.NOTES
Auteur     : Kevin Gaonach  
Site Web   : https://github.com/kevin-gaonach/it-tips/  
Version    : 1.0  
Date       : 2025-07-25

.EXAMPLE
.\Install-WinGetApps.ps1

Lance le script et affiche une selection d'application a installer avec WinGet.

#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Verifie si le script est execute en tant qu'administrateur
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ce script necessite des privileges administrateur. Relance avec elevation..." -ForegroundColor Red
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

Write-Host "Script execute avec les droits administrateur.`n" -ForegroundColor Green

$progressPreference = 'silentlyContinue'

# Verifie si WinGet est deja disponible
$wingetModuleInstalled = Get-Module -ListAvailable -Name "Microsoft.WinGet.Client"

if (!($wingetModuleInstalled)) {
    Write-Host "Installation du module WinGet PowerShell depuis PSGallery..." -ForegroundColor Blue
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Write-Host "Execution de Repair-WinGetPackageManager pour initialisation..." -ForegroundColor Blue
    Repair-WinGetPackageManager
    Write-Host "Installation de WinGet terminee." -ForegroundColor Green
}


function Show-AppInstallerGUI {
    $form = New-Object Windows.Forms.Form
    $form.Text = "WinGet"
    $form.Size = New-Object Drawing.Size(800, 730)
    $form.StartPosition = "CenterScreen"
    $form.AutoScroll = $true

    $titleLabel = New-Object Windows.Forms.Label
    $titleLabel.Text = "Applications list by Kevin Gaonach"
    $titleLabel.Font = New-Object Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::Crimson
    $titleLabel.Size = New-Object Drawing.Size(360, 25)
    $titleLabel.Location = New-Object Drawing.Point(200, 5)
    $form.Controls.Add($titleLabel)

    $categories = @{
        "Developpement" = @{
            "GitHub Desktop" = "GitHub.GitHubDesktop"
        }
        "Communication" = @{
            "Discord" = "Discord.Discord"
        }
        "Admins" = @{
            "PuTTY" = "PuTTY.PuTTY"
            "WinSCP" = "WinSCP.WinSCP"
            "mRemoteNG" = "mRemoteNG.mRemoteNG"
        }
        "Streaming" = @{
            "StreamDeck" = "Elgato.StreamDeck"
            "OBS Studio" = "OBSProject.OBSStudio"
        }
        "Monitoring" = @{
            "Rivatuner Statistics Server" = "Guru3D.RTSS"
            "Afterburner" = "Guru3D.Afterburner"
            "OCCT" = "OCBase.OCCT.Personal"
        }
        "Gaming" = @{
            "Amazon Games" = "Amazon.Games"
            "EA Desktop" = "ElectronicArts.EADesktop"
            "Epic Games" = "EpicGames.EpicGamesLauncher"
            "Playnite" = "Playnite.Playnite"
            "Steam" = "Valve.Steam"
            "Ubisoft Connect" = "Ubisoft.Connect"
            "GOG Galaxy" = "GOG.Galaxy"
        }
        "Systeme" = @{
            "TunnelBear VPN" = "TunnelBear.TunnelBear"
            "Veeam Agent" = "Veeam.VeeamAgent"
            "WinDirStat" = "WinDirStat.WinDirStat"
            "WingetUI" = "MartiCliment.UniGetUI"
            "System Informer" = "WinsiderSS.SystemInformer"
            "TeamViewer" = "TeamViewer.TeamViewer"
        }
        "Bureautique" = @{
            "PDFsam" = "PDFsam.PDFsam"
            "Adobe Reader" = "Adobe.Acrobat.Reader.64-bit"
            "Chrome" = "Google.Chrome"
            "Firefox" = "Mozilla.Firefox.fr"
            "7-Zip" = "7zip.7zip"
            "Ant Renamer" = "AntSoftware.AntRenamer"
            "KeePassXC" = "KeePassXCTeam.KeePassXC"
            "VLC" = "VideoLAN.VLC"
            "Greenshot" = "Greenshot.Greenshot"
            "Notepad++" = "Notepad++.Notepad++"
        }
    }

    $checkboxes = @{}
    $currentY = 40
    $padding = 10
    $checkboxWidth = 180
    $checkboxHeight = 22
    $formWidth = $form.ClientSize.Width

    foreach ($category in $categories.Keys) {
        # Label de categorie
        $label = New-Object Windows.Forms.Label
        $label.Text = "$category"
        $label.Font = New-Object Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $label.Location = New-Object Drawing.Point($padding, $currentY)
        $label.Size = New-Object Drawing.Size(700, 20)
        $form.Controls.Add($label)
        $currentY += 25

        # Calcul du nombre de colonnes selon la largeur disponible
        $columnsPerRow = [math]::Floor(($formWidth - 2 * $padding) / $checkboxWidth)
        if ($columnsPerRow -lt 1) { $columnsPerRow = 1 }

        $appList = @($categories[$category].Keys)
        for ($i = 0; $i -lt $appList.Count; $i++) {
            $column = $i % $columnsPerRow
            $row = [math]::Floor($i / $columnsPerRow)

            $x = $padding + ($column * $checkboxWidth)
            $y = $currentY + ($row * $checkboxHeight)

            $checkbox = New-Object Windows.Forms.CheckBox
            $checkbox.Text = $appList[$i]
            $checkbox.Width = $checkboxWidth - 10
            $checkbox.Location = New-Object Drawing.Point($x, $y)
            $checkbox.Checked = $true
            $form.Controls.Add($checkbox)

            $checkboxes[$appList[$i]] = $checkbox
        }

        $rowsUsed = [math]::Ceiling($appList.Count / $columnsPerRow)
        $currentY += ($rowsUsed * $checkboxHeight) + 15
    }

    # Bouton d’installation
    $installButton = New-Object Windows.Forms.Button
    $installButton.Text = "Installer les applications selectionnees"
    $installButton.Width = 200
    $installButton.Height = 40
    $installButton.Location = New-Object Drawing.Point(180, $currentY)
    $form.Controls.Add($installButton)

    # Bouton de mise a jour
    $updateButton = New-Object Windows.Forms.Button
    $updateButton.Text = "Mettre a jour les applications"
    $updateButton.Width = 200
    $updateButton.Height = 40
    $updateButton.Location = New-Object Drawing.Point(420, $currentY)
    $form.Controls.Add($updateButton)

    $installButton.Add_Click({
        $selectedApps = @()
        foreach ($category in $categories.Keys) {
            foreach ($appName in $categories[$category].Keys) {
                if ($checkboxes[$appName].Checked) {
                    $selectedApps += $categories[$category][$appName]
                }
            }
        }

        if ($selectedApps.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Aucune application selectionnee.", "Info", "OK", "Information")
            return
        }

        foreach ($id in $selectedApps) {
            Write-Host "Installation de $id..." -ForegroundColor Cyan
            try {
                winget install --id $id --silent --accept-source-agreements --accept-package-agreements
            } catch {
                Write-Host "echec de l'installation : $id" -ForegroundColor Red
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Installation terminee.", "Termine", "OK", "Information")
        $form.Close()
    })

    $updateButton.Add_Click({
        Write-Host "Mise a jour de toutes les applications installees via WinGet..." -ForegroundColor Blue
        winget upgrade --all --accept-source-agreements --accept-package-agreements
        Write-Host "Mise a jour terminee." -ForegroundColor Green
        [System.Windows.Forms.MessageBox]::Show("Mise a jour terminee.", "Succes", "OK", "Information")
        $form.Close()
    })

    [void]$form.ShowDialog()
}


Show-AppInstallerGUI