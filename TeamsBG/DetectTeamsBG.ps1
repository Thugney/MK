<#
    
    Description:  to verify the presence of 8 custom Teams background images
                 in the new Teams client directory (%APPDATA%\Microsoft\Teams\meetingbackgroundsdatastore).
    pilot
#>

$ErrorActionPreference = "Stop"
$LogPath = "$env:LOCALAPPDATA\CustomLogs\TeamsBackgrounds_Detect.log"
$TeamsBackgroundPath = "$env:APPDATA\Microsoft\Teams\meetingbackgroundsdatastore"
$ImageNames = @(
    "mk_teamsbakgrunn_gamlegaarden tulipaner.png",
    "mk_teamsbakgrunn_foss.png",
    "mk_teamsbakgrunn_blå bølge.png",
    "mk_teamsbakgrunn_hoppsenter vinter.png",
    "mk_teamsbakgrunn_vei sommer.png",
    "mk_teamsbakgrunn_i skogen sommer.png",
    "mk_teamsbakgrunn_solnedgang vinter.png",
    "mk_teamsbakgrunn_vann sommer.png"
)

# Opprett loggkatalog hvis den ikke eksisterer
if (-not (Test-Path -Path (Split-Path $LogPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null
}

# Initialiser logg
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starter deteksjonsskript" | Out-File -FilePath $LogPath -Append

# Sjekk om Teams-bakgrunnskatalog eksisterer
if (-not (Test-Path -Path $TeamsBackgroundPath)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Teams-bakgrunnskatalog ikke funnet: $TeamsBackgroundPath" | Out-File -FilePath $LogPath -Append
    exit 1
}

# Sjekk for alle bilder
$allImagesPresent = $true
foreach ($image in $ImageNames) {
    $imagePath = Join-Path -Path $TeamsBackgroundPath -ChildPath $image
    if (-not (Test-Path -Path $imagePath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Manglende bilde: $image" | Out-File -FilePath $LogPath -Append
        $allImagesPresent = $false
    }
}

if ($allImagesPresent) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Alle bilder er til stede. Ingen remediering nødvendig." | Out-File -FilePath $LogPath -Append
    exit 0
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Ett eller flere bilder mangler. Remediering nødvendig." | Out-File -FilePath $LogPath -Append
    exit 1
}