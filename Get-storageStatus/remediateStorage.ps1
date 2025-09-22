<#
.SYNOPSIS
Intune Remediation: Run Disk Cleanup for low space on C: drive.
#>

# Possible Values (safe to add/remove):
# 'Active Setup Temp Folders', 'BranchCache', 'Content Indexer Cleaner', 'Device Driver Packages', 'Downloaded Program Files', 
# 'GameNewsFiles', 'GameStatisticsFiles', 'GameUpdateFiles', 'Internet Cache Files', 'Memory Dump Files', 'Offline Pages Files', 
# 'Old ChkDsk Files', 'Previous Installations', 'Recycle Bin', 'Service Pack Cleanup', 'Setup Log Files', 'System error memory dump files',
# 'System error minidump files', 'Temporary Files', 'Temporary Setup Files', 'Temporary Sync Files', 'Thumbnail Cache', 'Update Cleanup', 
# 'Upgrade Discarded Files', 'User file versions', 'Windows Defender', 'Windows Error Reporting Archive Files', 
# 'Windows Error Reporting Queue Files', 'Windows Error Reporting System Archive Files', 'Windows Error Reporting System Queue Files', 
# 'Windows ESD installation files', 'Windows Upgrade Log Files'

# Selected cleanup types (originals + additions for more effective space recovery)
$cleanupTypeSelection = @(
    'Temporary Sync Files', 
    'Downloaded Program Files', 
    'Memory Dump Files', 
    'Recycle Bin',
    'Temporary Files',          # Core temp cleanup
    'Thumbnail Cache',          # Icon caches
    'Update Cleanup',           # Windows Update files (uncommented for better results)
    'Internet Cache Files',     # Browser caches
    'Setup Log Files',          # Installation logs
    'Temporary Setup Files',    # Temp setup files
    #'Windows Upgrade Log Files' # Upgrade logs
)

try {
    # Clear any existing StateFlags to avoid conflicts
    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\*" -Name "StateFlags0001" -ErrorAction SilentlyContinue | 
        Remove-ItemProperty -Name "StateFlags0001" -ErrorAction SilentlyContinue

    # Set flags for selected cleanups
    foreach ($keyName in $cleanupTypeSelection) {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$keyName"
        if (Test-Path $regPath) {
            New-ItemProperty -Path $regPath -Name "StateFlags0001" -Value 2 -PropertyType DWord -Force | Out-Null
            Write-Output "Enabled cleanup for: $keyName"
        } else {
            Write-Output "Warning: Cleanup type '$keyName' not available on this system"
        }
    }

    # Run Disk Cleanup silently
    Write-Output "Starting Disk Cleanup (/sagerun:1)..."
    $process = Start-Process -FilePath "CleanMgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -PassThru -Wait -NoNewWindow
    if ($process.ExitCode -eq 0) {
        Write-Output "Disk Cleanup completed successfully."
        exit 0
    } else {
        Write-Output "Disk Cleanup failed (Exit Code: $($process.ExitCode))."
        exit 1
    }
} catch {
    Write-Output "Error during remediation: $($_.Exception.Message)"
    exit 1
}