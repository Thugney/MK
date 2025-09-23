# Check TPM status; trigger remediation if not ready or owned with issues
try {
    $tpm = Get-Tpm
    if ($tpm.TpmPresent -and !$tpm.TpmReady) {
        Write-Output "TPM is present but not ready. Remediation needed."
        exit 1  # Issue detected
    } elseif ($tpm.TpmOwned -and (Get-TpmEndorsementKeyInfo -ErrorAction SilentlyContinue) -eq $null) {
        Write-Output "TPM owned but endorsement key issue. Remediation needed."
        exit 1
    } else {
        Write-Output "TPM is fine."
        exit 0  # No issue
    }
} catch {
    Write-Output "Error checking TPM: $_. Assuming issue."
    exit 1
}