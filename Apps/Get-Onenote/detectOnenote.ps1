<#
    .Descriptions
        detect skriptet sjekker om OneNote er installert
        1 - Hvis OneNote finnes  = (Not compliant) trigger remediation
        2 - Hvis OneNote ikke finnes = (compliant) trenges ikke remediation
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
    .Version
        Pilot

#>

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage  # For Intune output
    # Append to file for persistence
    $logFile = "$env:TEMP\OneNoteDetection_$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

$AppName = "Microsoft.Office.OneNote"
$ScriptName = "OneNote-UWP-Detection"

try {
    Write-Log "[$ScriptName] Starting OneNote UWP detection..."

    # Check for OneNote UWP package across all users
    Write-Log "[$ScriptName] Checking installed packages: $AppName"
    $InstalledApps = Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue
    
    # Check for provisioned packages
    Write-Log "[$ScriptName] Checking provisioned packages: $AppName"
    $ProvisionedApps = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $AppName } -ErrorAction SilentlyContinue

    if ($InstalledApps -or $ProvisionedApps) {
        # App found - log details
        $InstalledCount = ($InstalledApps | Measure-Object).Count
        $ProvisionedCount = ($ProvisionedApps | Measure-Object).Count
        Write-Log "[$ScriptName] OneNote UWP detected: $InstalledCount installed on user(s), $ProvisionedCount provisioned"

        # Log details for troubleshooting
        if ($InstalledApps) {
            foreach ($AppInstance in $InstalledApps) {
                $Version = $AppInstance.Version
                $InstallLocation = $AppInstance.InstallLocation
                $UserSID = $AppInstance.Sid  # May be null for system-wide
                Write-Log "[$ScriptName] Installed: Version $Version at $InstallLocation (SID: $UserSID)"
            }
        }
        if ($ProvisionedApps) {
            foreach ($ProvInstance in $ProvisionedApps) {
                $Version = $ProvInstance.Version
                Write-Log "[$ScriptName] Provisioned: Version $Version"
            }
        }
        
        Write-Log "[$ScriptName] DETECTION: OneNote UWP is present - remediation needed"
        exit 1  # Triggers remediation
    } else {
        Write-Log "[$ScriptName] OneNote UWP is not installed or provisioned on this device"
        Write-Log "[$ScriptName] NO ACTION NEEDED: OneNote UWP not detected"
        exit 0  # Compliant
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log "[$ScriptName] ERROR: Failed to detect OneNote UWP - $ErrorMessage" "ERROR"
    exit 1  # Treat errors as non-compliant
}

Write-Log "[$ScriptName] Detection completed."