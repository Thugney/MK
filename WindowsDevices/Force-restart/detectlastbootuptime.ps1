<#
.SYNOPSIS
     skript trygger en omstart
.DESCRIPTION
    skriptet sjekker omstart dato standard: 7 dager
.PARAMETER RestartDelayMinutes
    Antall minutter før omstart (standard: 10)
.Author
    robwol
#>
param (
    [int]$RestartDelayMinutes = 10
)

$ToastScriptPath = "C:\MK-automation\toast.ps1"
$LogPath = "C:\ProgramData\MK-automation\RemediationLog.txt"
$LockFile = "$env:TEMP\ToastLock_$(Get-Date -Format 'yyyyMMdd').txt"

# Log function with error handling
function Write-Log {
    param ($Message)
    try {
        $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
        Add-Content -Path $LogPath -Value $LogMessage -Force -ErrorAction Stop
    } catch {
        Write-Output $LogMessage
    }
}

# Ensure log directory exists
$LogDir = Split-Path $LogPath -Parent
if (-not (Test-Path $LogDir)) {
    try {
        New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Failed to create log directory: $_"
    }
}

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
    Write-Log "Logged-on user: $LoggedOnUser"
} catch {
    Write-Log "Error getting logged-on user: $($_.Exception.Message)"
}

# Prevent multiple runs today
if (Test-Path $LockFile) {
    $LastRun = Get-Item $LockFile | Select-Object -ExpandProperty LastWriteTime
    if ((Get-Date) - $LastRun -lt (New-TimeSpan -Hours 24)) {
        Write-Log "Lock file exists and less than 24 hours old. Skipping remediation."
        Write-Output "Remediation skipped due to recent run."
        exit 0
    }
}
New-Item -ItemType File -Path $LockFile -Force | Out-Null
Write-Log "Created lock file: $LockFile"

# Trigger toast if user logged in and toast.ps1 exists
if ($LoggedOnUser -and (Test-Path $ToastScriptPath)) {
    try {
        $TaskName = "ShowToastNotification_$((New-Guid).Guid)"
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Cleaned up existing task: $TaskName"
        }

        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ToastScriptPath`""
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(2)
        $Principal = New-ScheduledTaskPrincipal -UserId $LoggedOnUser -LogonType Interactive -RunLevel Limited
        $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Log "Toast task registered and will trigger once: $TaskName"

        Start-Sleep -Seconds 5
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Toast task cleaned up"
    } catch {
        Write-Log "Failed to handle toast task: $($_.Exception.Message)"
    }
} else {
    Write-Log "No logged-on user or toast script not found at $ToastScriptPath. Skipping toast."
}

# Schedule forced restart
try {
    $DelaySeconds = $RestartDelayMinutes * 60
    $ShutdownArgs = "/r /f /t $DelaySeconds /d p:0:0"
    $ShutdownResult = Start-Process -FilePath "shutdown.exe" -ArgumentList $ShutdownArgs -NoNewWindow -PassThru -Wait
    if ($ShutdownResult.ExitCode -eq 0) {
        Write-Log "Restart scheduled in $RestartDelayMinutes minutes using shutdown.exe"
        Write-Output "Remediation completed: Toast triggered, restart scheduled."
        exit 0
    } else {
        Write-Log "Shutdown command failed with exit code: $($ShutdownResult.ExitCode)"
        throw "Failed to schedule restart"
    }
} catch {
    Write-Log "Failed to schedule restart: $($_.Exception.Message)"
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
        Write-Log "Removed lock file: $LockFile"
    }
}