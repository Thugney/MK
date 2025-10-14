<#
.SYNOPSIS
    .Descriptions
        detection skriptet sjekkr IntuneManagementExtension
        1 - Hvis IntuneManagementExtension kjører ikke (Not compliant) trigger remediation
        2 - Hvis IntuneManagementExtension status kjører (compliant) trenges ikke remediation
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
   


troubleshooting, review IME logs at 
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log for any errors.
#>

try {
    $imeService = Get-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue
    $serviceStatus = if ($imeService) { $imeService.Status.ToString() } else { "Missing" }

    if ($imeService -and $serviceStatus -eq "Running") {
        Write-Output "Compliant: IME service running (Status: $serviceStatus)."
        exit 0
    } else {
        Write-Output "Non-Compliant: IME not available (Service: $serviceStatus)."
        exit 1
    }
} catch {
    Write-Output "Error checking IME: $($_.Exception.Message)"
    exit 1
}

