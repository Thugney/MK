# Detection: Check for pending Windows Updates.
# Exit 0 = Compliant (no updates); Exit 1 = Non-Compliant (updates available)

try {
    # Install PSWindowsUpdate if needed (Intune runs as SYSTEM, so safe)
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
    }
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    $updates = Get-WUList -MicrosoftUpdate | Where-Object { $_.Type -eq "Software" -and $_.IsHidden -eq $false }
    
    if ($updates) {
        $updateCount = $updates.Count
        Write-Output "Non-Compliant: $updateCount pending Windows Update(s) found."
        exit 1
    } else {
        Write-Output "Compliant: No pending Windows Updates."
        exit 0
    }
} catch {
    Write-Output "Error checking updates: $($_.Exception.Message)"
    exit 1  # Fail safe: Assume non-compliant on error
}