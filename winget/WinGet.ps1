Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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


function Show-AppInstallerGUI {
    $form = New-Object Windows.Forms.Form
    $form.Text = "WinGet"
    $form.Size = New-Object Drawing.Size(360, 990)
	
    $form.StartPosition = "CenterScreen"

	$titleLabel = New-Object Windows.Forms.Label
	$titleLabel.Text = "❤ Applications list by Kevin Gaonach ❤"
	$titleLabel.Font = New-Object Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
	$titleLabel.ForeColor = [System.Drawing.Color]::Crimson
	$titleLabel.Size = New-Object Drawing.Size(320, 25)
	$titleLabel.Location = New-Object Drawing.Point(10, 5)
	$form.Controls.Add($titleLabel)

    $categories = @{
        "Développement" = @{
            "GitHub Desktop" = "GitHub.GitHubDesktop"
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
        "Système" = @{
            "TunnelBear VPN" = "TunnelBear.TunnelBear"
            "Veeam Agent" = "Veeam.VeeamAgent"
            "WinDirStat" = "WinDirStat.WinDirStat"
            "WingetUI" = "MartiCliment.UniGetUI"
            "System Informer" = "WinsiderSS.SystemInformer"
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
    $y = 35

    foreach ($category in $categories.Keys) {
        # 🏷️ Affichage du nom de la catégorie
        $label = New-Object Windows.Forms.Label
        $label.Text = "$category"
        $label.Font = New-Object Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $label.Location = New-Object Drawing.Point(10, $y)
        $label.Size = New-Object Drawing.Size(700, 20)
        $form.Controls.Add($label)
        $y += 25

        foreach ($appName in $categories[$category].Keys) {
            $checkbox = New-Object Windows.Forms.CheckBox
            $checkbox.Text = "$appName"
            $checkbox.Location = New-Object Drawing.Point(30, $y)
            $checkbox.Width = 700
            $checkbox.Checked = $true
            $form.Controls.Add($checkbox)
            $checkboxes[$appName] = $checkbox
            $y += 20
        }

        $y += 10
    }

    # 🚀 Bouton d’installation
    $installButton = New-Object Windows.Forms.Button
    $installButton.Text = "Installer les applications sélectionnées"
    $installButton.Width = 150
    $installButton.Height = 40
    $installButton.Location = New-Object Drawing.Point(20, $y)
    $form.Controls.Add($installButton)

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
            [System.Windows.Forms.MessageBox]::Show("Aucune application sélectionnée.", "Info", "OK", "Information")
            return
        }

        foreach ($id in $selectedApps) {
            Write-Host "Installation de $id..." -ForegroundColor Cyan
            try {
                winget install --id $id --silent --accept-source-agreements --accept-package-agreements
            } catch {
                Write-Host "Échec de l'installation : $id" -ForegroundColor Red
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Installation terminée.", "Terminé", "OK", "Information")
		$form.Close()


})
		
		# 🔄 Bouton de mise à jour
		$updateButton = New-Object Windows.Forms.Button
		$updateButton.Text = "Mettre à jour les applications installées"
		$updateButton.Width = 150
		$updateButton.Height = 40
		$updateButton.Location = New-Object Drawing.Point(180, $y)
		$form.Controls.Add($updateButton)
		
		$updateButton.Add_Click({
		Write-Host "Mise à jour de toutes les applications installées via WinGet..." -ForegroundColor Blue
        winget upgrade --all --accept-source-agreements --accept-package-agreements
        Write-Host "Mise à jour terminée." -ForegroundColor Green
        [System.Windows.Forms.MessageBox]::Show("Mise à jour terminée.", "Succès", "OK", "Information")
		$form.Close()
    })

    [void]$form.ShowDialog()
}

Show-AppInstallerGUI
