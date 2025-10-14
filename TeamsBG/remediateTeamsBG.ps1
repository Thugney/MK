<#
    Author: robwol
    Description: download 8 custom Teams background images from intranet URLs
                 and place them in the new Teams client directory (%APPDATA%\Microsoft\Teams\meetingbackgroundsdatastore).
   pilot
#>


$ErrorActionPreference = "Stop"
$LogPath = "$env:LOCALAPPDATA\CustomLogs\TeamsBackgrounds_Remediate.log"
$TeamsBackgroundPath = "$env:APPDATA\Microsoft\Teams\meetingbackgroundsdatastore"

# Erstatt med dine GitHub raw-URLer (f.eks. https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_gamlegaarden%20tulipaner.png)
$ImageUrls = @(
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_gamlegaarden%20tulipaner.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_foss.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_bl%C3%A5%20b%C3%B8lge.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_hoppsenter%20vinter.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_vei%20sommer.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_i%20skogen%20sommer.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_solnedgang%20vinter.png",
    "https://raw.githubusercontent.com/Thugney/MK/main/MSteamsBackground/mk_teamsbakgrunn_vann%20sommer.png"
)

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
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starter remedieringsskript for bruker: $env:USERNAME" | Out-File -FilePath $LogPath -Append

# Sjekk BitsTransfer-tilgjengelighet (som bedt om)
if (-not (Get-Module -ListAvailable -Name BitsTransfer)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - BitsTransfer-modulen er ikke tilgjengelig. Prøver Invoke-WebRequest som fallback." | Out-File -FilePath $LogPath -Append
    $useBitsTransfer = $false
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - BitsTransfer-modulen er tilgjengelig." | Out-File -FilePath $LogPath -Append
    $useBitsTransfer = $true
}

# Opprett Teams-bakgrunnskatalog hvis den ikke eksisterer
if (-not (Test-Path -Path $TeamsBackgroundPath)) {
    try {
        New-Item -ItemType Directory -Path $TeamsBackgroundPath -Force | Out-Null
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Opprettet katalog: $TeamsBackgroundPath" | Out-File -FilePath $LogPath -Append
    } catch {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Feil ved opprettelse av katalog: $_" | Out-File -FilePath $LogPath -Append
        exit 1
    }
}

# Last ned bilder
for ($i = 0; $i -lt $ImageUrls.Count; $i++) {
    $imageName = $ImageNames[$i]
    $sourceUrl = $ImageUrls[$i]
    $destinationPath = Join-Path -Path $TeamsBackgroundPath -ChildPath $imageName

    # Hopp over hvis bildet allerede eksisterer
    if (Test-Path -Path $destinationPath) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Bildet eksisterer allerede: $imageName" | Out-File -FilePath $LogPath -Append
        continue
    }

    # Last ned med retry-logikk
    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            if ($useBitsTransfer) {
                Start-BitsTransfer -Source $sourceUrl -Destination $destinationPath -ErrorAction Stop
            } else {
                Invoke-WebRequest -Uri $sourceUrl -OutFile $destinationPath -ErrorAction Stop
            }
            $success = $true
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Nedlasting vellykket: $imageName fra $sourceUrl" | Out-File -FilePath $LogPath -Append
        } catch {
            $retryCount++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Forsøk $retryCount mislyktes for imageName: $_" | Out-File -FilePath $LogPath -Append
            if ($retryCount -eq $maxRetries) {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Maks antall forsøk nådd for $imageName. Hopper over." | Out-File -FilePath $LogPath -Append
                continue
            }
            Start-Sleep -Seconds 5
        }
    }
}

# Verifiser at alle bilder ble lastet ned
$allImagesPresent = $true
foreach ($image in $ImageNames) {
    $imagePath = Join-Path -Path $TeamsBackgroundPath -ChildPath $image
    if (-not (Test-Path -Path $imagePath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Verifisering mislyktes: $image ikke funnet" | Out-File -FilePath $LogPath -Append
        $allImagesPresent = $false
    }
}

if ($allImagesPresent) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Remediering fullført vellykket. Alle bilder deployert." | Out-File -FilePath $LogPath -Append
    exit 0
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Remediering ufullstendig. Noen bilder mislyktes i deployering." | Out-File -FilePath $LogPath -Append
    exit 1
}