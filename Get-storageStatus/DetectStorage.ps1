# Detection: Check if C: drive has at least 15GB free space.
# Exit 0 = Compliant (free >= 10GB); Exit 1 = Non-Compliant (free < 10GB)

$storageThresholdGB = 10
$freeSpaceBytes = (Get-PSDrive | Where-Object { $_.Name -eq "C" }).Free

if ($freeSpaceBytes -ge ($storageThresholdGB * 1GB)) {
    Write-Output "Compliant: Free space ($([math]::Round($freeSpaceBytes / 1GB, 2)) GB) >= threshold ($storageThresholdGB GB)"
    exit 0
} else {
    Write-Output "Non-Compliant: Free space ($([math]::Round($freeSpaceBytes / 1GB, 2)) GB) < threshold ($storageThresholdGB GB)"
    exit 1
}