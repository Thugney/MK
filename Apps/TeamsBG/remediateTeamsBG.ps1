<#
.SYNOPSIS
    Distribuerer 8 egendefinerte Teams-bakgrunnsbilder til ny Teams-klient med GUID-navn og miniatyrbilder.
.DESCRIPTION
    Laster ned bilder fra GitHub, genererer GUID-navn og miniatyrbilder, plasserer dem i riktig mappe, tvinger Teams-initialisering, fikser tillatelser og sletter cache for oppdatering.
.PARAMETER None
.EXAMPLE
    .\TeamsBackgrounds_Remediate.ps1
.NOTES
    Forfatter: robwol
    Versjon: 2.2
    Dato: 15. oktober 2025
    Pilot: Oppdatert for GUID-naming og miniatyrgenerering basert på manuell opplastingstest.
#>
$ErrorActionPreference = "Stop"
$LogPath = "$env:LOCALAPPDATA\CustomLogs\TeamsBackgrounds_Remediate.log"
$TeamsBackgroundPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"
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

# Opprett loggkatalog hvis den ikke eksisterer
if (-not (Test-Path -Path (Split-Path $LogPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null
}

# Initialiser logg
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starter remedieringsskript for bruker: $env:USERNAME" | Out-File -FilePath $LogPath -Append

# Sjekk BitsTransfer-tilgjengelighet
if (-not (Get-Module -ListAvailable -Name BitsTransfer)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - BitsTransfer-modulen er ikke tilgjengelig. Prøver Invoke-WebRequest som fallback." | Out-File -FilePath $LogPath -Append
    $useBitsTransfer = $false
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - BitsTransfer-modulen er tilgjengelig." | Out-File -FilePath $LogPath -Append
    $useBitsTransfer = $true
}

# Sjekk om ny Teams er installert
if (-not (Get-AppxPackage -Name MSTeams)) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Ny Teams ikke installert ennå. Avslutter for retry." | Out-File -FilePath $LogPath -Append
    exit 0  # Intune vil retry
}

# Tving Teams-initialisering for å unngå sletting av filer
try {
    Stop-Process -Name "ms-teams" -Force -ErrorAction SilentlyContinue
    Start-Process "ms-teams://" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
    Stop-Process -Name "ms-teams" -Force -ErrorAction SilentlyContinue
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Teams initialisert vellykket." | Out-File -FilePath $LogPath -Append
} catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Feil ved Teams-initialisering: $_" | Out-File -FilePath $LogPath -Append
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

# Fiks tillatelser på mappen
try {
    $acl = Get-Acl $TeamsBackgroundPath
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl -Path $TeamsBackgroundPath -AclObject $acl
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Tillatelser fikset på $TeamsBackgroundPath" | Out-File -FilePath $LogPath -Append
} catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Feil ved fikse tillatelser: $_" | Out-File -FilePath $LogPath -Append
}

# Last ned, generer GUID, miniatyr og kopier bilder
Add-Type -AssemblyName System.Drawing
$processedImages = @()
for ($i = 0; $i -lt $ImageUrls.Count; $i++) {
    $sourceUrl = $ImageUrls[$i]
    $tempPath = "$env:TEMP\temp_image_$i.png"
    $guid = (New-Guid).ToString()
    $newName = "$guid.png"
    $thumbName = "$guid_thumb.png"
    $destinationPath = Join-Path -Path $TeamsBackgroundPath -ChildPath $newName
    $thumbPath = Join-Path -Path $TeamsBackgroundPath -ChildPath $thumbName

    # Hopp over hvis både bilde og miniatyr allerede eksisterer
    if ((Test-Path $destinationPath) -and (Test-Path $thumbPath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Bilde og miniatyr eksisterer allerede: $newName" | Out-File -FilePath $LogPath -Append
        $processedImages += $guid
        continue
    }

    # Last ned med retry-logikk
    $maxRetries = 3
    $retryCount = 0
    $success = $false
    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            if ($useBitsTransfer) {
                Start-BitsTransfer -Source $sourceUrl -Destination $tempPath -ErrorAction Stop
            } else {
                Invoke-WebRequest -Uri $sourceUrl -OutFile $tempPath -ErrorAction Stop
            }
            $success = $true
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Nedlasting vellykket: $tempPath fra $sourceUrl" | Out-File -FilePath $LogPath -Append
        } catch {
            $retryCount++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Forsøk $retryCount mislyktes for sourceUrl: $_" | Out-File -FilePath $LogPath -Append
            if ($retryCount -eq $maxRetries) {
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Maks antall forsøk nådd for $sourceUrl. Hopper over." | Out-File -FilePath $LogPath -Append
                continue
            }
            Start-Sleep -Seconds 5
        }
    }

    if ($success) {
        # Kopier til GUID-navn
        Copy-Item -Path $tempPath -Destination $destinationPath -Force

        # Generer miniatyr (360x360)
        try {
            $img = [System.Drawing.Image]::FromFile($tempPath)
            $thumb = $img.GetThumbnailImage(360, 360, $null, [IntPtr]::Zero)
            $thumb.Save($thumbPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $img.Dispose()
            $thumb.Dispose()
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Generert og kopiert $newName og $thumbName" | Out-File -FilePath $LogPath -Append
            $processedImages += $guid
        } catch {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Feil ved miniatyrgenerering for newName: $_" | Out-File -FilePath $LogPath -Append
        }

        # Slett temp-fil
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    }
}

# Slett Teams-cache for å tvinge oppdatering
$cachePaths = @(
    "$env:APPDATA\Microsoft\Teams\Cache",
    "$env:APPDATA\Microsoft\Teams\GPUCache",
    "$env:APPDATA\Microsoft\Teams\Code Cache",
    "$env:APPDATA\Microsoft\Teams\IndexedDB"
)
foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Slettet cache-mappe: $path" | Out-File -FilePath $LogPath -Append
    }
}

# Verifiser at alle bilder ble prosessert
$allImagesPresent = $true
foreach ($guid in $processedImages) {
    $imagePath = Join-Path -Path $TeamsBackgroundPath -ChildPath "$guid.png"
    $thumbPath = Join-Path -Path $TeamsBackgroundPath -ChildPath "$guid_thumb.png"
    if (-not (Test-Path $imagePath) -or -not (Test-Path $thumbPath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Verifisering mislyktes: $guid mangler bilde eller miniatyr" | Out-File -FilePath $LogPath -Append
        $allImagesPresent = $false
    }
}

if ($allImagesPresent -and $processedImages.Count -eq $ImageUrls.Count) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Remediering fullført vellykket. Alle bilder deployert." | Out-File -FilePath $LogPath -Append
    exit 0
} else {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Remediering ufullstendig. Noen bilder mislyktes i deployering." | Out-File -FilePath $LogPath -Append
    exit 1
}