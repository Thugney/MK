<#
    .Descriptions
        remediate skript forsøker å fjerne OneNote
    
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
    .Version
        Pilot

#>

#Requires -RunAsAdministrator  # Intune runs as SYSTEM, but keeps for local testing

param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage  # For Intune output
    # Append to file for persistence
    $logFile = "$env:TEMP\OneNoteRemediation_$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

$AppName = "Microsoft.Office.OneNote"
$ScriptName = "OneNote-UWP-Remediation"

try {
    Write-Log "[$ScriptName] Starting OneNote UWP remediation..."

    if ($WhatIf) {
        Write-Log "[$ScriptName] WHATIF: Would remove $AppName for all users and deprovision" "WHATIF"
        return  # Exit early for dry run
    }

    # Remove OneNote UWP from all users
    Write-Log "[$ScriptName] Removing installed packages: $AppName"
    $InstalledApps = Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue
    if ($InstalledApps) {
        $InstalledApps | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Log "[$ScriptName] Removed $($InstalledApps.Count) installed instance(s)"
    } else {
        Write-Log "[$ScriptName] No installed packages found"
    }

    # Remove provisioned package (prevents new user installs)
    Write-Log "[$ScriptName] Removing provisioned packages: $AppName"
    $ProvisionedApps = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $AppName } -ErrorAction SilentlyContinue
    if ($ProvisionedApps) {
        $ProvisionedApps | Remove-AppxProvisionedPackage -Online -ErrorAction Stop
        Write-Log "[$ScriptName] Removed $($ProvisionedApps.Count) provisioned instance(s)"
    } else {
        Write-Log "[$ScriptName] No provisioned packages found"
    }

    # Verify removal
    Start-Sleep -Seconds 5  # Brief pause for system to update
    $PostCheckInstalled = Get-AppxPackage -Name $AppName -AllUsers -ErrorAction SilentlyContinue
    $PostCheckProvisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $AppName } -ErrorAction SilentlyContinue

    if (-not $PostCheckInstalled -and -not $PostCheckProvisioned) {
        Write-Log "[$ScriptName] REMEDIATION: OneNote UWP removal verified - clean" "SUCCESS"
        exit 0
    } else {
        Write-Log "[$ScriptName] REMEDIATION: Partial removal - retry may be needed" "WARNING"
        exit 1  # Signal failure for retry
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log "[$ScriptName] ERROR: Remediation failed - $ErrorMessage" "ERROR"
    exit 1
}

Write-Log "[$ScriptName] Remediation completed."