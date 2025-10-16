<#
.SYNOPSIS
    Skript for å planlegge en omstart av enheten
.DESCRIPTION
    Kjører hvis detect-skriptet finner enheter som ikke er omstartet på mer enn 7 dager.
    Varsler brukeren med en toast-melding umiddelbart og planlegger en omstart.
.PARAMETER RestartDelayMinutes
    Minutter å vente før tvungen omstart (standard: 10)
.NOTES
    Author: robwol (revised for fixes)
#>

# Parameters
param (
    [int]$RestartDelayMinutes = 10
)
$ToastScriptPath = "C:\MK-automation\toast.ps1"
$LogPath = "C:\ProgramData\MK-automation\RemediationLog.txt"

# Calculate times
$CurrentTime = Get-Date
$ToastTriggerTime = $CurrentTime.AddSeconds(10)  # Trigger toast almost immediately
$ScheduledRestartTime = $CurrentTime.AddMinutes($RestartDelayMinutes)
$ToastDate = $ToastTriggerTime.ToString("yyyy-MM-dd")
$ToastTime = $ToastTriggerTime.ToString("HH:mm")
$RestartDate = $ScheduledRestartTime.ToString("yyyy-MM-dd")
$RestartTime = $ScheduledRestartTime.ToString("HH:mm")

# Log function
function Write-Log {
    param ($Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Add-Content -Path $LogPath -Value $LogMessage -Force
}

# Ensure log directory exists
$LogDir = Split-Path $LogPath -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Get logged-on user
$LoggedOnUser = $null
try {
    $LoggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop).UserName
    if ($LoggedOnUser) {
        $LoggedOnUser = $LoggedOnUser.Trim()
        Write-Log "Logged-on user: $LoggedOnUser"
    } else {
        Write-Log "No logged-on user found. Skipping toast but proceeding with restart schedule."
    }
}
catch {
    Write-Log "Error getting logged-on user: $($_.Exception.Message)"
}

# Check power state (optional: skip restart if on battery)
$SkipOnBattery = $true  # Set to $false if you want to proceed anyway
try {
    $Battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($Battery -and $Battery.BatteryStatus -eq 1 -and $SkipOnBattery) {  # 1 = Discharging (on battery)
        Write-Log "Device is on battery. Skipping restart schedule."
        Write-Output "Remediation skipped due to battery power."
        Exit 0
    } else {
        Write-Log "Device is on power or no battery detected."
    }
}
catch {
    Write-Log "Error checking power state: $($_.Exception.Message). Proceeding anyway."
}

# Schedule and run toast notification task as logged-on user (immediately)
try {
    if ($LoggedOnUser -and (Test-Path $ToastScriptPath)) {
        # Optional: Pass args to toast script (e.g., delay in minutes; customize based on your toast.ps1)
        $ToastArgs = "-DelayMinutes $RestartDelayMinutes"
        $ToastCommand = "schtasks /create /tn ShowToastNotification /tr `"powershell.exe -ExecutionPolicy Bypass -File \`"$ToastScriptPath\`" $ToastArgs`" /sc once /sd $ToastDate /st $ToastTime /ru `"$LoggedOnUser`" /rl LIMITED /f"
        $ToastResult = Invoke-Expression $ToastCommand
        Write-Log "Toast notification task created: $ToastResult"

        # Verify creation
        $ToastTask = schtasks /query /tn ShowToastNotification /fo csv | ConvertFrom-Csv
        if (-not $ToastTask) { throw "Toast task not created." }

        # Run the task immediately (since trigger is set for ~10 sec from now, this ensures it starts)
        Start-Sleep -Seconds 5  # Brief wait for task registration
        schtasks /run /tn ShowToastNotification
        Write-Log "Toast task triggered."

        # Clean up task after a delay (give time for toast to show)
        Start-Sleep -Seconds 30
        schtasks /delete /tn ShowToastNotification /f
        Write-Log "Toast task cleaned up."
    } else {
        Write-Log "No logged-on user or toast script not found at $ToastScriptPath. Skipping toast."
    }
}
catch {
    Write-Log "Failed to handle toast notification: $($_.Exception.Message)"
}

# Schedule restart task as SYSTEM (in future)
try {
    $RestartCommand = "schtasks /create /tn IntuneForcedRestart /tr `"shutdown.exe /r /f /t 10 /d p:0:0 /c 'Planlagt omstart av IT-avdelingen'`" /sc once /sd $RestartDate /st $RestartTime /ru SYSTEM /rl HIGHEST /f"
    $RestartResult = Invoke-Expression $RestartCommand
    Write-Log "Restart task scheduled for $RestartDate $RestartTime: $RestartResult"

    # Verify creation (no need to run yet; it will auto-run at time)
    $RestartTask = schtasks /query /tn IntuneForcedRestart /fo csv | ConvertFrom-Csv
    if (-not $RestartTask) { throw "Restart task not created." }

    # Optional: Clean up restart task after it runs (but since it reboots, it may self-clean; add if needed)
}
catch {
    Write-Log "Failed to schedule restart task: $($_.Exception.Message)"
    throw
}

# Final output
try {
    Write-Output "Remediation completed. Toast triggered; restart scheduled for $RestartDate $RestartTime."
    Write-Log "Remediation completed successfully."
    Exit 0
}
catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    Write-Log "Remediation failed: $($_.Exception.Message)"
    Exit 1
}