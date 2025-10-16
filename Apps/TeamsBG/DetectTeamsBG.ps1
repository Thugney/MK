<#
.SYNOPSIS
    Verifiserer tilstedeværelse av 8 egendefinerte Teams-bakgrunnsbilder i ny Teams-klient.
.DESCRIPTION
    Sjekker om minst 8 bilder og miniatyrbilder med GUID-navn eksisterer i riktig mappe.
.PARAMETER None
.EXAMPLE
    .\TeamsBackgrounds_Detect.ps1
.NOTES
    Forfatter: robwol
    Versjon: 2.2
    Dato: 15. oktober 2025
    Pilot: Oppdatert for å sjekke GUID-baserte filer og miniatyrbilder.
#>
$ErrorActionPreference = "Stop"
$LogPath = "$env:LOCALAPPDATA\CustomLogs\TeamsBackgrounds_Detect.log"
$TeamsBackgroundPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

# Opprett loggkatalog hvis den ikke eksisterer
if (-not (Test-Path -Path (Split-Path $LogPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null
}

# Initialiser logg
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starter deteksjonsskript for bruker: $env:USERNAME" | Out-File -FilePath $LogPath -Append

# Sjekk om ny Teams er installert
if (-not (Get-AppxPackage -Name MSTeams)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Ny Teams ikke installert." | Out-File -FilePath $LogPath -Append
    exit 1
}

# Sjekk om Teams-bakgrunnskatalog eksisterer
if (-not (Test-Path -Path $TeamsBackgroundPath)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Teams-bakgrunnskatalog ikke funnet: $TeamsBackgroundPath" | Out-File -FilePath $LogPath -Append
    exit 1
}

# Sjekk antall bilder og miniatyrbilder (minst 8 av hver)
$imageFiles = Get-ChildItem -Path $TeamsBackgroundPath -Filter "*.png" | Where-Object { $_.Name -notlike "*_thumb.png" -and $_.Name -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$' }
$thumbFiles = Get-ChildItem -Path $TeamsBackgroundPath -Filter "*_thumb.png"
$expectedCount = 8

if ($imageFiles.Count -ge $expectedCount -and $thumbFiles.Count -ge $expectedCount) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Alle minst $expectedCount bilder og miniatyrbilder er til stede. Ingen remediering nødvendig." | Out-File -FilePath $LogPath -Append
    exit 0
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Ett eller flere bilder mangler (Bilder: $($imageFiles.Count)/$expectedCount, Miniatyrbilder: $($thumbFiles.Count)/$expectedCount). Remediering nødvendig." | Out-File -FilePath $LogPath -Append
    exit 1
}