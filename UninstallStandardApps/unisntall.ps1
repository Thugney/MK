# Fjern tag-fil for å tillate re-installasjon 

# Definer tag-sti
$TagPath = "$env:ProgramData\Microsoft\RemoveW10Bloatware"
$TagFile = "$TagPath\RemoveW10Bloatware.ps1.tag"
$LogFile = "$TagPath\RemoveW10Bloatware_Uninstall.log"

# Start logging
Start-Transcript -Path $LogFile -Append

# Sjekk og fjern tag-fil
if (Test-Path $TagFile) {
    Write-Host "Fjerner tag-fil: $TagFile"
    try {
        Remove-Item -Path $TagFile -Force -ErrorAction Stop
    } catch {
        Write-Warning "Kunne ikke fjerne tag-fil: $_"
    }
} else {
    Write-Host "Tag-fil finnes ikke - ingen handling nødvendig"
}

# Stopp logging
Stop-Transcript