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
    $form.Size = New-Object Drawing.Size(360, 1070)
	
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
        "GitHub Desktop - Interface graphique pour GitHub" = "GitHub.GitHubDesktop"
    }
    "Communication" = @{
        "Discord - Chat vocal / texte" = "Discord.Discord"
    }
    "Admins" = @{
        "PuTTY - Client SSH/Telnet" = "PuTTY.PuTTY"
        "WinSCP - Transfert de fichiers SFTP/FTP" = "WinSCP.WinSCP"
        "mRemoteNG - Gestionnaire de connexions RDP/SSH" = "mRemoteNG.mRemoteNG"
    }
    "Streaming" = @{
        "StreamDeck - Contrôle de scènes et macros" = "Elgato.StreamDeck"
        "OBS Studio - Logiciel de streaming/recording" = "OBSProject.OBSStudio"
    }
    "Monitoring" = @{
        "Rivatuner - Affichage stats CPU/GPU en jeu" = "Guru3D.RTSS"
        "Afterburner - Overclocking et monitoring GPU" = "Guru3D.Afterburner"
        "OCCT - Test de stabilité CPU/GPU et PSU" = "OCBase.OCCT.Personal"
    }
    "Gaming" = @{
        "Amazon Games - Lanceur de jeux Amazon" = "Amazon.Games"
        "EA Desktop - Lanceur de jeux  EA" = "ElectronicArts.EADesktop"
        "Epic Games - Lanceur de jeux Epic Games" = "EpicGames.EpicGamesLauncher"
        "Playnite - Bibliothèque unifiée de jeux" = "Playnite.Playnite"
        "Steam - Lanceur de jeux Steam" = "Valve.Steam"
        "Ubisoft Connect - Lanceur de jeux  Ubisoft" = "Ubisoft.Connect"
        "GOG Galaxy - Lanceur de jeux GOG" = "GOG.Galaxy"
    }
    "Système" = @{
        "TunnelBear VPN - VPN simple et visuel" = "TunnelBear.TunnelBear"
        "Veeam Agent - Sauvegarde/restauration système" = "Veeam.VeeamAgent"
        "WinDirStat - Analyse de l'espace disque" = "WinDirStat.WinDirStat"
        "WingetUI - Interface graphique pour winget" = "MartiCliment.UniGetUI"
        "System Informer - Gestionnaire de tâches avancé" = "WinsiderSS.SystemInformer"
        "TeamViewer - Accès distant sécurisé" = "TeamViewer.TeamViewer"
    }
    "Bureautique" = @{
        "PDFsam - Fusion/split de PDF" = "PDFsam.PDFsam"
        "Adobe Reader - Lecteur PDF officiel" = "Adobe.Acrobat.Reader.64-bit"
        "Chrome - Navigateur rapide de Google" = "Google.Chrome"
        "Firefox - Navigateur libre & respectueux de la vie privée" = "Mozilla.Firefox.fr"
        "7-Zip - Compression/décompression de fichiers" = "7zip.7zip"
        "Ant Renamer - Renommage de fichiers en masse" = "AntSoftware.AntRenamer"
        "KeePassXC - Gestionnaire de mots de passe" = "KeePassXCTeam.KeePassXC"
        "VLC - Lecteur multimédia universel" = "VideoLAN.VLC"
        "Greenshot - Capture d’écran simple et efficace" = "Greenshot.Greenshot"
        "Notepad++ - Éditeur de texte" = "Notepad++.Notepad++"
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
