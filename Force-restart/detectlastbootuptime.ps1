<#
.SYNOPSIS
    Detect skript siste omstartsdato 
.DESCRIPTION
    skriptet sjekker omstart dato standard: 7 dager
.PARAMETER MaxDaysWithoutRestart
    Antall dager tillatt uten omstart før utløses en omstart (standard: 7)
.Author
    robwol
#>

$MaxDaysWithoutRestart = 7

function Get-LastRebootTime {
    $BootEvents = Get-WinEvent -ProviderName "Microsoft-Windows-Kernel-Boot" -MaxEvents 10 -ErrorAction SilentlyContinue |
                  Where-Object { $_.Id -eq 27 -and ($_.Message -match "0x0" -or $_.Message -match "0x1") }
    if ($BootEvents) {
        return ($BootEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
    } else {
        return (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
}

$LastReboot = Get-LastRebootTime
$UptimeDays = [math]::Round(((Get-Date) - $LastReboot).TotalDays)

if ($UptimeDays -ge $MaxDaysWithoutRestart) {
    Write-Output "Device has not been rebooted in $UptimeDays days (>= $MaxDaysWithoutRestart)."
    exit 1
} else {
    Write-Output "Device was rebooted $UptimeDays days ago (< $MaxDaysWithoutRestart)."
    exit 0
}