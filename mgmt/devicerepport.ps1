<#
.SYNOPSIS
    Audit and verify Autopilot devices before removal based on multiple criteria.

.DESCRIPTION
    This script creates a comprehensive audit report of Autopilot devices cross-referenced
    with their Intune status to help identify truly stale devices that are safe to remove.
    It NEVER removes devices automatically - only generates reports for manual review.

.PARAMETER DaysInactive
    Number of days since last Intune sync to flag a device for review (you define this)

.EXAMPLE
    .\Audit-AutopilotDevices.ps1 -DaysInactive 120
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$DaysInactive
)

function Connect-ToGraph {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    
    try {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "DeviceManagementServiceConfig.Read.All", "User.Read.All" -ErrorAction Stop
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit 1
    }
}

function Get-DeviceDetailedStatus {
    Write-Host "`nGathering comprehensive device information..." -ForegroundColor Cyan
    
    $cutoffDate = (Get-Date).AddDays(-$DaysInactive)
    Write-Host "Flagging devices with no sync since: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
    
    # Get all Intune managed devices
    Write-Host "Retrieving all Intune managed devices..." -ForegroundColor Cyan
    $intuneDevices = Get-MgDeviceManagementManagedDevice -All
    Write-Host "Found $($intuneDevices.Count) devices in Intune" -ForegroundColor White
    
    # Get all Autopilot devices
    Write-Host "Retrieving all Autopilot devices..." -ForegroundColor Cyan
    $autopilotDevices = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities" -Method GET
    $allAutopilotDevices = $autopilotDevices.value
    Write-Host "Found $($allAutopilotDevices.Count) devices in Autopilot" -ForegroundColor White
    
    # Cross-reference and build comprehensive report
    $report = @()
    
    foreach ($apDevice in $allAutopilotDevices) {
        Write-Host "Processing Autopilot device: $($apDevice.serialNumber)..." -ForegroundColor Gray
        
        # Find matching Intune device by serial number
        $intuneDevice = $intuneDevices | Where-Object { $_.SerialNumber -eq $apDevice.serialNumber }
        
        if ($intuneDevice) {
            # Device exists in both Autopilot and Intune
            $daysSinceSync = $null
            $syncStatus = "Unknown"
            
            if ($intuneDevice.LastSyncDateTime) {
                $daysSinceSync = ((Get-Date) - $intuneDevice.LastSyncDateTime).Days
                
                if ($intuneDevice.LastSyncDateTime -lt $cutoffDate) {
                    $syncStatus = "FLAGGED - No sync for $daysSinceSync days"
                } else {
                    $syncStatus = "Active - Synced $daysSinceSync days ago"
                }
            }
            
            # Get primary user info
            $primaryUser = "None"
            $userEmail = "None"
            if ($intuneDevice.UserId) {
                try {
                    $user = Get-MgUser -UserId $intuneDevice.UserId -ErrorAction SilentlyContinue
                    if ($user) {
                        $primaryUser = $user.DisplayName
                        $userEmail = $user.UserPrincipalName
                    }
                } catch {
                    $primaryUser = "Error retrieving user"
                }
            }
            
            $report += [PSCustomObject]@{
                DeviceName = $intuneDevice.DeviceName
                SerialNumber = $apDevice.serialNumber
                Model = $apDevice.model
                Manufacturer = $apDevice.manufacturer
                AutopilotID = $apDevice.id
                IntuneID = $intuneDevice.Id
                InIntune = "Yes"
                InAutopilot = "Yes"
                LastSyncDateTime = $intuneDevice.LastSyncDateTime
                DaysSinceLastSync = $daysSinceSync
                SyncStatus = $syncStatus
                EnrollmentState = $apDevice.enrollmentState
                DeploymentProfileAssigned = if ($apDevice.deploymentProfileAssignmentStatus) { $apDevice.deploymentProfileAssignmentStatus } else { "None" }
                ComplianceState = $intuneDevice.ComplianceState
                OSVersion = $intuneDevice.OSVersion
                PrimaryUser = $primaryUser
                UserEmail = $userEmail
                ManagementState = $intuneDevice.ManagementState
                IsEncrypted = $intuneDevice.IsEncrypted
                AzureADRegistered = $intuneDevice.AzureADRegistered
                AutopilotEnrolled = $apDevice.enrollmentState
                GroupTag = $apDevice.groupTag
                RecommendedAction = if ($syncStatus -like "FLAGGED*") { "REVIEW - Verify with user/manager before removal" } else { "KEEP - Device is active" }
            }
        }
        else {
            # Device in Autopilot but NOT in Intune
            $report += [PSCustomObject]@{
                DeviceName = "Not in Intune"
                SerialNumber = $apDevice.serialNumber
                Model = $apDevice.model
                Manufacturer = $apDevice.manufacturer
                AutopilotID = $apDevice.id
                IntuneID = "N/A"
                InIntune = "No"
                InAutopilot = "Yes"
                LastSyncDateTime = "Never synced"
                DaysSinceLastSync = "N/A"
                SyncStatus = "ORPHANED - In Autopilot only"
                EnrollmentState = $apDevice.enrollmentState
                DeploymentProfileAssigned = if ($apDevice.deploymentProfileAssignmentStatus) { $apDevice.deploymentProfileAssignmentStatus } else { "None" }
                ComplianceState = "N/A"
                OSVersion = "N/A"
                PrimaryUser = "N/A"
                UserEmail = "N/A"
                ManagementState = "N/A"
                IsEncrypted = "N/A"
                AzureADRegistered = "N/A"
                AutopilotEnrolled = $apDevice.enrollmentState
                GroupTag = $apDevice.groupTag
                RecommendedAction = "SAFE TO REMOVE - Device never enrolled or already retired from Intune"
            }
        }
    }
    
    return $report
}

# Main execution
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Autopilot Device Audit & Verification Report" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Inactivity Threshold: $DaysInactive days" -ForegroundColor White
Write-Host "Report Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "========================================================`n" -ForegroundColor Cyan

Write-Host "WARNING: This script only generates reports." -ForegroundColor Yellow
Write-Host "         No devices will be automatically removed." -ForegroundColor Yellow
Write-Host "         Manual verification is required before any removal.`n" -ForegroundColor Yellow

# Connect to Microsoft Graph
Connect-ToGraph

# Get comprehensive device report
$auditReport = Get-DeviceDetailedStatus

if ($auditReport.Count -eq 0) {
    Write-Host "`nNo devices found. Exiting." -ForegroundColor Yellow
    Disconnect-MgGraph
    exit 0
}

# Categorize devices
$flaggedDevices = $auditReport | Where-Object { $_.SyncStatus -like "FLAGGED*" }
$orphanedDevices = $auditReport | Where-Object { $_.InIntune -eq "No" }
$activeDevices = $auditReport | Where-Object { $_.SyncStatus -like "Active*" }

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "Summary Statistics" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Total Autopilot Devices: $($auditReport.Count)" -ForegroundColor White
Write-Host "Active Devices (synced recently): $($activeDevices.Count)" -ForegroundColor Green
Write-Host "Flagged Devices (no sync for $DaysInactive+ days): $($flaggedDevices.Count)" -ForegroundColor Yellow
Write-Host "Orphaned Devices (in Autopilot but not in Intune): $($orphanedDevices.Count)" -ForegroundColor Red

# Export reports
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Full report
$fullReportPath = ".\AutopilotAudit_Full_$timestamp.csv"
$auditReport | Export-Csv -Path $fullReportPath -NoTypeInformation
Write-Host "`nFull Audit Report: $fullReportPath" -ForegroundColor Cyan

# Flagged devices report (requires review)
if ($flaggedDevices.Count -gt 0) {
    $flaggedReportPath = ".\AutopilotAudit_FlaggedForReview_$timestamp.csv"
    $flaggedDevices | Export-Csv -Path $flaggedReportPath -NoTypeInformation
    Write-Host "Flagged Devices (REVIEW REQUIRED): $flaggedReportPath" -ForegroundColor Yellow
    
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "FLAGGED DEVICES - MANUAL VERIFICATION REQUIRED" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "These devices haven't synced in $DaysInactive+ days." -ForegroundColor Yellow
    Write-Host "Before removing, you MUST verify:" -ForegroundColor Yellow
    Write-Host "  1. Contact the primary user or their manager" -ForegroundColor White
    Write-Host "  2. Confirm device is not on extended leave/storage" -ForegroundColor White
    Write-Host "  3. Check if device is broken/lost/stolen" -ForegroundColor White
    Write-Host "  4. Verify device is not being repaired" -ForegroundColor White
    Write-Host "  5. Confirm device is approved for decommissioning`n" -ForegroundColor White
    
    $flaggedDevices | Select-Object DeviceName, SerialNumber, DaysSinceLastSync, PrimaryUser, UserEmail, LastSyncDateTime | Format-Table -AutoSize
}

# Orphaned devices report (safe to remove)
if ($orphanedDevices.Count -gt 0) {
    $orphanedReportPath = ".\AutopilotAudit_OrphanedDevices_$timestamp.csv"
    $orphanedDevices | Export-Csv -Path $orphanedReportPath -NoTypeInformation
    Write-Host "Orphaned Devices (likely safe to remove): $orphanedReportPath" -ForegroundColor Cyan
    
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "ORPHANED DEVICES - In Autopilot but NOT in Intune" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "These devices are registered in Autopilot but never enrolled" -ForegroundColor Cyan
    Write-Host "or have been retired from Intune." -ForegroundColor Cyan
    Write-Host "These are generally safe to remove but verify first.`n" -ForegroundColor Cyan
    
    $orphanedDevices | Select-Object SerialNumber, Model, EnrollmentState, GroupTag | Format-Table -AutoSize
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "1. Review the exported CSV files" -ForegroundColor White
Write-Host "2. For FLAGGED devices: Contact users/managers for verification" -ForegroundColor White
Write-Host "3. For ORPHANED devices: Verify these are truly unused" -ForegroundColor White
Write-Host "4. Create a removal list of VERIFIED stale devices" -ForegroundColor White
Write-Host "5. Use a separate removal script with your verified list`n" -ForegroundColor White

Write-Host "REMINDER: Never remove devices without proper verification!" -ForegroundColor Yellow
Write-Host "          Check with users, managers, and IT records first.`n" -ForegroundColor Yellow

Disconnect-MgGraph
Write-Host "Audit completed." -ForegroundColor Green