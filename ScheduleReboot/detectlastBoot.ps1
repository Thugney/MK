<#
.SYNOPSIS
    Detect skript siste omstartsdato 
.DESCRIPTION
    skriptet sjekker omstart dato standard: 7 dager
.PARAMETER MaxDaysWithoutRestart
    Antall dager tillatt uten omstart før utløses en omstart (standard: 7)
#>

param (
    [int]$MaxDaysWithoutRestart = 7
)

$Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime

if ($Uptime.Days -ge $MaxDaysWithoutRestart) {
    Write-Output "Enheten har ikke blitt omstartet på $($Uptime.Days) dager."
    Exit 1
} else {
    Write-Output "Enheten ble omstartet for $($Uptime.Days) dager siden."
    Exit 0
}