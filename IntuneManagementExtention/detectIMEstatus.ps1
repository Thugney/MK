<#
.SYNOPSIS
Detect if Intune Management Extension (IME) is installed and running.
Exit 0 = Compliant; Exit 1 = Non-Compliant.
#>

try {
    $imeService = Get-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue
    $imeProcess = Get-Process -Name "Microsoft.Management.Services.IntuneWindowsAgent" -ErrorAction SilentlyContinue

    $serviceStatus = if ($imeService) { $imeService.Status.ToString() } else { "Missing" }
    $processCount = if ($imeProcess) { $imeProcess.Count } else { 0 }

    if ($imeService -and $serviceStatus -eq "Running" -and $processCount -gt 0) {
        Write-Output "Compliant: IME service running (Status: $serviceStatus; Processes: $processCount)."
        exit 0
    } else {
        Write-Output "Non-Compliant: IME not available (Service: $serviceStatus; Processes: $processCount)."
        exit 1
    }
} catch {
    Write-Output "Error checking IME: $($_.Exception.Message)"
    exit 1
}

