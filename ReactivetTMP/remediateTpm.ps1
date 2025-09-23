# Request TPM clear using WMI (sets physical presence request)
try {
    # Get WMI TPM object
    $tpm = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTpm" -Class Win32_Tpm
    if ($tpm -ne $null) {
        # Set request to clear TPM (value 5: Clear TPM)
        $result = $tpm.SetPhysicalPresenceRequest(5)
        if ($result.ReturnValue -eq 0) {
            Write-Output "TPM clear request set successfully. Reboot required to complete."
            # Optional: Force reboot (uncomment if needed, but notify users)
            # Restart-Computer -Force
        } else {
            Write-Output "Failed to set TPM clear request. Error code: $($result.ReturnValue)"
            exit 1
        }
    } else {
        Write-Output "TPM WMI object not found."
        exit 1
    }
    
    # Optional: Post-clear initialization (run after reboot in a separate remediation if needed)
    # Initialize-Tpm -AllowClear
} catch {
    Write-Output "Error during remediation: $_"
    exit 1
}
exit 0