# Opprett tag- og loggkataloger
$TagPath = "$env:ProgramData\Microsoft\RemoveW10Bloatware"
if (-not (Test-Path $TagPath)) {
    New-Item -Path $TagPath -ItemType Directory -Force
}

# Opprett tag-fil for Intune-deteksjon
Set-Content -Path "$TagPath\RemoveW10Bloatware.ps1.tag" -Value "Installed"

# Start logging
Start-Transcript -Path "$TagPath\RemoveW10Bloatware.log"

# Liste over innebygde apper å fjerne
$UninstallPackages = @(
    "Microsoft.Getstarted",
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GamingApp",
    "Microsoft.WindowsAlarms",
    "Microsoft.GetHelp",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.Office.OneNote",
    "Microsoft.OneConnect",
    "Microsoft.SkypeApp",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
    #"WidgetBoard.exe"  # Merk: Dette er ikke en standard Appx-pakke; håndter separat hvis nødvendig (f.eks. via prosessstopp eller uninstall.exe)
)

# Hent installerte og provisjonerte pakker
$InstalledPackages = Get-AppxPackage -AllUsers | Where-Object { $UninstallPackages -contains $_.Name }
$ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $UninstallPackages -contains $_.DisplayName }

# Fjern provisjonerte pakker
foreach ($ProvPackage in $ProvisionedPackages) {
    Write-Host "Fjerner provisjonert pakke: $($ProvPackage.DisplayName)"
    try {
        Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
    } catch {
        Write-Warning "Kunne ikke fjerne provisjonert pakke: $($ProvPackage.DisplayName)"
    }
}

# Fjern installerte Appx-pakker
foreach ($AppxPackage in $InstalledPackages) {
    Write-Host "Fjerner Appx-pakke: $($AppxPackage.Name)"
    try {
        Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
    } catch {
        Write-Warning "Kunne ikke fjerne Appx-pakke: $($AppxPackage.Name)"
    }
}

# Stopp logging
Stop-Transcript