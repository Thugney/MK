<#
    .Descriptions
        remediate skriptet  re-installere servicecertificte for App relaiability - vise i intune rapport om app reliability
        
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
    .Version
        Pilot

#>

# Logging for Intune
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogPath\ServiceCertRemediation_$(Get-Date -Format 'yyyyMMdd').log"
if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting remediation" -Force

try {
    $query = "SELECT * FROM CCM_PendingPolicyState WHERE PolicyID='B27D9CFC-84AD-0AF8-9DF1-23EE05E8C05D'"
    $wmiService = Get-WmiObject -Namespace "root\ccm\policyagent" -Class "__NAMESPACE" -ErrorAction Stop  # Ensure namespace access
    $wmiObjs = Get-WmiObject -Query $query -Namespace "root\ccm\policyagent" -ErrorAction Stop
    
    $fixed = $false
    foreach ($wmiPendingPolicy in $wmiObjs) {
        if ($wmiPendingPolicy.State -eq 1) {
            Add-Content -Path $LogFile -Value "$(Get-Date) - Found pending policy. Resetting state to force re-download." -Force
            $wmiPendingPolicy.State = 0
            $result = $wmiPendingPolicy.Put_()
            
            if ($result.ReturnValue -eq 0) {
                Add-Content -Path $LogFile -Value "$(Get-Date) - Successfully updated policy state." -Force
                $fixed = $true
            } else {
                Add-Content -Path $LogFile -Value "$(Get-Date) - Failed to update policy. ReturnValue: $($result.ReturnValue)" -Force
                throw "Policy update failed."
            }
        }
    }
    
    if ($fixed) {
        Add-Content -Path $LogFile -Value "$(Get-Date) - Remediation complete. Check Endpoint Analytics in 72 hours." -Force
        Write-Output "Success: ServiceCertificate policy re-download triggered."
        exit 0
    } else {
        Add-Content -Path $LogFile -Value "$(Get-Date) - No pending policy found - no action needed." -Force
        Write-Output "No remediation needed."
        exit 0
    }
} catch {
    Add-Content -Path $LogFile -Value "$(Get-Date) - Error: $($_.Exception.Message)" -Force
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
}