# C Drive Space Remediation Script
# Cleans up common locations to free disk space
 
try {
    Write-Output "Starting disk cleanup remediation"
    
    $cleanupPaths = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:SystemRoot\Logs\*",
        "$env:SystemRoot\Prefetch\*",
        "$env:LocalAppData\Microsoft\Windows\Temporary Internet Files\*",
        "$env:LocalAppData\Temp\*",
        "$env:SystemRoot\SoftwareDistribution\Download\*"
    )
    
    $totalCleaned = 0
    
    foreach ($path in $cleanupPaths) {
        try {
            Write-Output "Cleaning: $path"
            $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                try {
                    $size = if ($item.PSIsContainer) { 0 } else { $item.Length }
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    $totalCleaned += $size
                }
                catch {
                    # Continue with next item if deletion fails
                }
            }
        }
        catch {
            # Continue with next path if access fails
        }
    }
    
    # Run Disk Cleanup utility
    Write-Output "Running system disk cleanup"
    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    
    # Check final disk space
    $cDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeSpaceGB = [math]::Round($cDrive.FreeSpace / 1GB, 2)
    $cleanedMB = [math]::Round($totalCleaned / 1MB, 2)
    
    Write-Output "Cleanup completed"
    Write-Output "Cleaned: $cleanedMB MB"
    Write-Output "Current free space: $freeSpaceGB GB"
    
    if ($freeSpaceGB -ge 10) {
        Write-Output "Remediation successful - sufficient space available"
        exit 0
    } else {
        Write-Output "Remediation completed but space still low"
        exit 1
    }
}
catch {
    Write-Output "Error during cleanup: $($_.Exception.Message)"
    exit 1
}