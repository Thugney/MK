#Requires -RunAsAdministrator
<#
.SYNOPSIS
Deteksjonsskript for ventende sikkerhetsoppdateringer.

.DESCRIPTION
Sjekker om enheten har ventende sikkerhets-, kumulative- eller kritiske oppdateringer.
Returnerer exit 1 hvis oppdateringer mangler (trigger remediation).

.NOTES
Krever forhåndsinstallert PSWindowsUpdate-modul via Intune Win32.
#>

try {
    # Importer modul (bør være forhåndsinstallert)
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Output "PSWindowsUpdate-modul mangler. Installer via Intune Win32."
        exit 1
    }
    Import-Module PSWindowsUpdate -ErrorAction Stop
    
    # Registrer event source om nødvendig
    if (-not [System.Diagnostics.EventLog]::SourceExists("IntuneSecurityUpdates")) {
        New-EventLog -LogName Application -Source "IntuneSecurityUpdates" -ErrorAction Stop
    }

    # Hent ventende oppdateringer
    $pendingUpdates = Get-WUList -MicrosoftUpdate | Where-Object { $_.Title -match 'Security|Cumulative|Critical' }
    
    if ($pendingUpdates.Count -gt 0) {
        Write-Output "Fant $($pendingUpdates.Count) ventende oppdateringer."
        Write-EventLog -LogName Application -Source "IntuneSecurityUpdates" -EventId 1000 -Message "Deteksjon: $($pendingUpdates.Count) ventende oppdateringer."
        exit 1  # Trigger remediation
    } else {
        Write-Output "Ingen ventende oppdateringer."
        Write-EventLog -LogName Application -Source "IntuneSecurityUpdates" -EventId 1000 -Message "Deteksjon: Ingen ventende oppdateringer."
        exit 0  # Compliant
    }
} catch {
    Write-Output "Deteksjon feilet: $($_.Exception.Message)"
    Write-EventLog -LogName Application -Source "IntuneSecurityUpdates" -EventId 1002 -EntryType Error -Message $_.Exception.Message
    exit 1
}