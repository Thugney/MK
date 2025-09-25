try {
    Write-Output "Starting disk cleanup remediation"# Set up registry for Disk Cleanup automation
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$cleanupOptions = @(
    "Active Setup Temp Folders",
    "BranchCache",
    "D3D Shader Cache",
    "Delivery Optimization Files",
    "Diagnostic Data Viewer database files",
    "Downloaded Program Files",
    "Internet Cache Files",
    "Offline Pages Files",
    "Old ChkDsk Files",
    "Previous Installations",
    "Recycle Bin",
    "RetailDemo Offline Content",
    "Service Pack Cleanup",
    "Setup Log Files",
    "System error memory dump files",
    "System error minidump files",
    "Temporary Files",
    "Temporary Setup Files",
    "Thumbnail Cache",
    "Update Cleanup",
    "Upgrade Discarded Files",
    "User file versions",
    "Windows Defender",
    "Windows Error Reporting Files",
    "Windows ESD installation files",
    "Windows Upgrade Log Files"
)
foreach ($option in $cleanupOptions) {
    $fullPath = "$regPath\$option"
    if (-not (Test-Path $fullPath)) {
        New-Item -Path $fullPath -Force | Out-Null
    }
    Set-ItemProperty -Path $fullPath -Name "StateFlags0001" -Value 2 -Type DWord -Force
}

# Cleanup file paths
$cleanupPaths = @(
    $env:TEMP,
    "$env:SystemRoot\Temp",
    "$env:SystemRoot\Logs",
    "$env:SystemRoot\Prefetch",
    "$env:LocalAppData\Microsoft\Windows\Temporary Internet Files",
    "$env:LocalAppData\Temp",
    "$env:SystemRoot\SoftwareDistribution\Download"
)

$totalCleaned = 0

# Stop Windows Update service before cleaning SoftwareDistribution
if (Test-Path "$env:SystemRoot\SoftwareDistribution\Download") {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
}

# Clean user profiles' temp folders
$userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($profile in $userProfiles) {
    $userTemp = "$($profile.FullName)\AppData\Local\Temp"
    $userInternetFiles = "$($profile.FullName)\AppData\Local\Microsoft\Windows\Temporary Internet Files"
    if (Test-Path $userTemp) { $cleanupPaths += $userTemp }
    if (Test-Path $userInternetFiles) { $cleanupPaths += $userInternetFiles }
}

foreach ($path in $cleanupPaths) {
    try {
        Write-Output "Cleaning: $path"
        # Pre-calculate size
        $size = (Get-ChildItem -Path $path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { $size = 0 }
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
        $totalCleaned += $size
    }
    catch {
        Write-Output "Warning: Failed to clean $path - $($_.Exception.Message)"
    }
}

# Restart Windows Update service
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

# Empty Recycle Bin
Write-Output "Emptying Recycle Bin"
Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue

# Run Disk Cleanup utility
Write-Output "Running system disk cleanup"
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

# Check final disk space
$cDrive = Get-Volume -DriveLetter C -ErrorAction SilentlyContinue
$freeSpaceGB = [math]::Round($cDrive.SizeRemaining / 1GB, 2)
$cleanedMB = [math]::Round($totalCleaned / 1MB, 2)

Write-Output "Cleanup completed"
Write-Output "Cleaned: $cleanedMB MB"
Write-Output "Current free space: $freeSpaceGB GB"


Write-Output "Remediation execution completed"
exit 0}
catch {
    Write-Output "Error during cleanup: $($_.Exception.Message)"
    exit 1
}
