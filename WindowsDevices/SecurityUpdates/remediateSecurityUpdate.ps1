#Requires -RunAsAdministrator
<#
.SYNOPSIS
Remediasjonsskript for sikkerhetsoppdateringer.

.DESCRIPTION
Installerer ventende oppdateringer kun i vedlikeholds-vindu (08:00-17:00).
Logger til fil og Event Viewer med validering.

.PARAMETER LogPath
Sti til loggfil. Standard: C:\MK-LogFiles\SecurityUpdateRemediation.log

.EXAMPLE
.\remediateSecurityUpdates.ps1 -LogPath C:\MK-LogFiles\SecurityUpdateRemediation.log

.NOTES
Krever forhåndsinstallert PSWindowsUpdate-modul via Intune Win32.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$LogPath = "C:\MK-LogFiles\SecurityUpdateRemediation.log"
)

try {
    # Sjekk vedlikeholds-vindu (08:00-17:00)
    $currentHour = (Get-Date).Hour
    if ($currentHour -lt 8 -or $currentHour -ge 17) {
        Write-Output "Utenfor vedlikeholds-vindu (08:00-17:00). Prøver senere."
        exit 1  # Trigger retry
    }

    # Importer modul
    Import-Module PSWindowsUpdate -ErrorAction Stop

    # Trigge skanning med UsoClient
    Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait -ErrorAction Stop
    Start-Sleep -Seconds 120  # Vent 120 sekunder med timeout
    $timeout = 600  # 10 minutter total timeout
    $elapsed = 0
    while ((Get-WUInstallerStatus).LastScanSuccess -eq $null -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 10
        $elapsed += 10
    }
    if ($elapsed -ge $timeout) {
        throw "Skanning tok for lang tid (over $timeout sekunder)."
    }

    # Hent ventende oppdateringer
    $pendingUpdates = Get-WUList -MicrosoftUpdate | Where-Object { $_.Title -match 'Security|Cumulative|Critical' }
    if ($pendingUpdates.Count -eq 0) {
        Write-Output "Ingen oppdateringer å installere."
        exit 0
    }

    # Installer oppdateringer
    $kbList = $pendingUpdates | ForEach-Object { $_.KBArticleIDs } | Where-Object { $_ }
    $installResult = Install-WindowsUpdate -KBArticleID $kbList -AcceptAll -IgnoreReboot -Verbose -ErrorAction Stop

    # Verifiser installasjon
    $installed = ($installResult | Where-Object { $_.Result -eq 'Installed' }).Count
    $failed = ($installResult | Where-Object { $_.Result -ne 'Installed' }).Count

    # Logg resultater
    $logEntry = @{
        Tidspunkt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Enhet = $env:COMPUTERNAME
        Installert = $installed
        Mislyktes = $failed
        Detaljer = ($installResult | Select-Object Title, Result, KB | ConvertTo-Json -Compress)
    }
    # Rotér loggfil (begrens til 10 MB)
    $maxSize = 10MB
    if (Test-Path $LogPath) {
        $fileSize = (Get-Item $LogPath).Length
        if ($fileSize -gt $maxSize) {
            $backup = "$LogPath.bak"
            if (Test-Path $backup) { Remove-Item $backup -Force }
            Rename-Item -Path $LogPath -NewName "$LogPath.bak"
        }
    }
    $logEntry | ConvertTo-Json | Out-File -FilePath $LogPath -Append

    # Logg til Event Viewer
    if ([System.Diagnostics.EventLog]::SourceExists("IntuneSecurityUpdates")) {
        $melding = "Installerte $installed oppdateringer. $failed mislyktes."
        Write-EventLog -LogName Application -Source "IntuneSecurityUpdates" -EventId 1001 -Message $melding
    }

    if ($failed -gt 0) {
        Write-Output "Delvis vellykket: $installed installert, $failed mislyktes."
        exit 1  # Trigger retry
    }

    Write-Output "Vellykket: $installed oppdateringer installert."
    exit 0
} catch {
    Write-Output "Remediasjon feilet: $($_.Exception.Message)"
    if ([System.Diagnostics.EventLog]::SourceExists("IntuneSecurityUpdates")) {
        Write-EventLog -LogName Application -Source "IntuneSecurityUpdates" -EventId 1002 -EntryType Error -Message $_.Exception.Message
    }
    exit 1
}