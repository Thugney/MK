<#
.SYNOPSIS
  .Descriptions
        remediation skriptet restarter IntuneManagementExtension
       
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
   
#>

try {
    $imeService = Get-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue

    if ($imeService) {
        Restart-Service -Name "IntuneManagementExtension" -Force
        Write-Output "Remediated: IME service restarted."
    } else {
        Write-Output "IME service not found. Manual reinstall may be needed (assign a Win32 app or PowerShell script in Intune to trigger installation)."
    }
} catch {
    Write-Output "Error remediating IME: $($_.Exception.Message)"
}