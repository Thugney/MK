<#
 .Descriptions
    Detection skript for Intune Proactive Remediation
    skriptet sjekkr om enkelte apper finnes
    Hvis finnes  1 = Found (Non-Compliant)
    hvis ikke innes Exit Codes: 0 = Not Found (Compliant)
    
.Author
    Robwol

#>

try {
    # Install/Import PSWindowsUpdate
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
    }
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    $updates = Get-WUList -MicrosoftUpdate | Where-Object { $_.Type -eq "Software" -and $_.IsHidden -eq $false }
    
    if (-not $updates) {
        Write-Output "No pending updates - nothing to remediate."
        exit 0
    }

    Write-Output "Installing $($updates.Count) pending Windows Update(s)..."
    
    # Install updates (non-interactive, auto-reboot suppress if possible)
    $result = Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:$false -IgnoreReboot -Confirm:$false
    
    if ($result -and $result.RebootRequired -eq $false) {
        Write-Output "Updates installed successfully (no reboot needed)."
        exit 0
    } elseif ($result.RebootRequired) {
        Write-Output "Updates installed; reboot recommended."
        exit 0  # Success, even if reboot pending
    } else {
        Write-Output "Failed to install updates."
        exit 1
    }
} catch {
    Write-Output "Error during remediation: $($_.Exception.Message)"
    exit 1
}