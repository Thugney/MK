<#
    .Descriptions
        detection skriptet sjekkr C disken
        1 - Hvis C Disken har mindre en 10G = (Not compliant) trigger remediation
        2 - Hvis status på C disk er mer en 10GB, (compliant) trenges ikke remediation
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
    .Version
        Pilot

#>
$storageThresholdGB = 10
$freeSpaceBytes = (Get-PSDrive | Where-Object { $_.Name -eq "C" }).Free

if ($freeSpaceBytes -ge ($storageThresholdGB * 1GB)) {
    Write-Output "Compliant: Free space ($([math]::Round($freeSpaceBytes / 1GB, 2)) GB) >= threshold ($storageThresholdGB GB)"
    exit 0
} else {
    Write-Output "Non-Compliant: Free space ($([math]::Round($freeSpaceBytes / 1GB, 2)) GB) < threshold ($storageThresholdGB GB)"
    exit 1
}