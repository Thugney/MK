try {
    # Start logging for Intune
    Start-Transcript -Path "C:\Windows\Temp\tpm_detection.log" -Append -ErrorAction SilentlyContinue

    Write-Output "Starting TPM detection for attestation issues"

    # Get TPM CIM instance
    $tpm = Get-CimInstance -Namespace "root\cimv2\Security\MicrosoftTpm" -ClassName Win32_Tpm
    if ($null -eq $tpm) {
        Write-Output "TPM not found - no remediation needed"
        Stop-Transcript
        exit 0
    }

    # Check if TPM is enabled, activated, and owned (proxy for needing clear due to attestation failures)
    if ($tpm.IsEnabled -and $tpm.IsActivated -and $tpm.IsOwned) {
        Write-Output "TPM is owned and ready - potential attestation issue detected, remediation needed"
        Stop-Transcript
        exit 1
    } else {
        Write-Output "TPM not in a state requiring clear - compliant"
        Stop-Transcript
        exit 0
    }
}
catch {
    Write-Output "Error in detection: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}