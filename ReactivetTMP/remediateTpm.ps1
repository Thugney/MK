<#
.SYNOPSIS
    Requests TPM clear using CIM for Intune remediation. Sets physical presence request for clear on reboot.
    Includes safety checks and logging.

.PARAMETER ForceReboot
    If $true, forces reboot after request (default: $false).

.PARAMETER SuspendBitLocker
    If $true, suspends BitLocker for 1 reboot if enabled (default: $true).
#>

param (
    [bool]$ForceReboot = $false,
    [bool]$SuspendBitLocker = $true
)

# Start logging for Intune
$logPath = "C:\Windows\Temp\tpm_clear.log"
Start-Transcript -Path $logPath -Append -ErrorAction SilentlyContinue

try {
    Write-Output "Starting TPM clear request remediation for attestation issues"

    # Get TPM CIM instance
    $tpm = Get-CimInstance -Namespace "root\cimv2\Security\MicrosoftTpm" -ClassName Win32_Tpm
    if ($null -eq $tpm) {
        Write-Output "TPM CIM instance not found. Skipping."
        Stop-Transcript
        exit 0
    }

    # Safety check: Verify TPM is enabled, activated, and owned
    if (-not $tpm.IsEnabled -or -not $tpm.IsActivated -or -not $tpm.IsOwned) {
        Write-Output "TPM not ready (not enabled, activated, or owned). Skipping."
        Stop-Transcript
        exit 0
    }

    # Safety check: Handle BitLocker if enabled
    $bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if ($bitlockerStatus -and $bitlockerStatus.ProtectionStatus -eq 'On') {
        Write-Output "BitLocker enabled on C:. TPM clear may require recovery key."
        if ($SuspendBitLocker) {
            Write-Output "Suspending BitLocker for 1 reboot."
            Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction Stop
        } else {
            Write-Output "BitLocker not suspended - proceed at risk."
        }
    }

    # Set physical presence request to clear TPM (5 = OwnerClear)
    $result = Invoke-CimMethod -InputObject $tpm -MethodName SetPhysicalPresenceRequest -Arguments @{Request = 5}
    if ($result.ReturnValue -eq 0) {
        Write-Output "TPM clear request set successfully (ReturnValue: 0). Reboot required to complete."
        if ($ForceReboot) {
            Write-Output "Forcing reboot to apply TPM clear."
            Restart-Computer -Force
        }
    } else {
        Write-Output "Failed to set TPM clear request. ReturnValue: $($result.ReturnValue)"
        Stop-Transcript
        exit 1
    }

    # Optional: Post-clear init (for separate post-reboot remediation if needed)
    # Initialize-Tpm -AllowClear -ErrorAction SilentlyContinue

    Write-Output "Remediation completed successfully."
    Stop-Transcript
    exit 0
}
catch {
    Write-Output "Error during remediation: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}