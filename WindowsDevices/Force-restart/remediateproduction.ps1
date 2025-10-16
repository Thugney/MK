<#
.SYNOPSIS
    Skript for å planlegge en omstart av enheten
.DESCRIPTION
    Kjører hvis detect-skriptet finner enheter som ikke er omstartet på mer enn 7 dager.
    Varsler brukeren med en toast-melding umiddelbart og planlegger en omstart.
.PARAMETER RestartDelayMinutes
    Minutter å vente før tvungen omstart (standard: 10)
.Author
    robwol
#>

param (
    [int]$RestartDelayMinutes = 10
)

$ToastScriptPath = "C:\MK-automation\toast.ps1"
$LockFile = "$env:TEMP\ToastLock_$(Get-Date -Format 'yyyyMMdd').txt"

# Get last reboot time
function Get-LastRebootTime {
    $BootEvents = Get-WinEvent -ProviderName "Microsoft-Windows-Kernel-Boot" -MaxEvents 10 -ErrorAction SilentlyContinue |
                  Where-Object { $_.Id -eq 27 -and ($_.Message -match "0x0" -or $_.Message -match "0x1") }
    if ($BootEvents) {
        return ($BootEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
    } else {
        return (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
}

# Calculate uptime
$LastReboot = Get-LastRebootTime
$UptimeDays = [math]::Round(((Get-Date) - $LastReboot).TotalDays)

# Get logged-on user
$LoggedOnUser = $null
try {
    $LoggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).UserName -replace '.*\\'
} catch {
    # Silent fail
}

# Check power state
$SkipOnBattery = $true
try {
    $Battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($Battery -and $Battery.BatteryStatus -eq 1 -and $SkipOnBattery) {
        Write-Output "Remediation skipped due to battery power."
        exit 0
    }
} catch {
    # Silent fail
}

# Prevent multiple runs today
if (Test-Path $LockFile) {
    $LastRun = Get-Item $LockFile | Select-Object -ExpandProperty LastWriteTime
    if ((Get-Date) - $LastRun -lt (New-TimeSpan -Hours 24)) {
        Write-Output "Remediation skipped due to recent run."
        exit 0
    }
}
New-Item -ItemType File -Path $LockFile -Force | Out-Null

# Trigger toast if user logged in and toast.ps1 exists
if ($LoggedOnUser -and (Test-Path $ToastScriptPath)) {
    try {
        $TaskName = "ShowToastNotification_$((New-Guid).Guid)"
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }

        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ToastScriptPath`""
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(2)
        $Principal = New-ScheduledTaskPrincipal -UserId $LoggedOnUser -LogonType Interactive -RunLevel Limited
        $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -Hidden -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

        Start-Sleep -Seconds 5
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        # Silent fail
    }
}

# Schedule forced restart without dialog
try {
    $DelaySeconds = $RestartDelayMinutes * 60
    $ShutdownArgs = "/r /f /t $DelaySeconds /d p:0:0"
    $ShutdownResult = Start-Process -FilePath "shutdown.exe" -ArgumentList $ShutdownArgs -NoNewWindow -PassThru -Wait
    if ($ShutdownResult.ExitCode -eq 0) {
        Write-Output "Remediation completed: Toast triggered, restart scheduled."
        exit 0
    } else {
        throw "Failed to schedule restart"
    }
} catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}