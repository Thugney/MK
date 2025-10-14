<#
 .Descriptions
    Detection skript for Intune Proactive Remediation
    skriptet sjekker 
    Hvis finnes  1 = Found (Non-Compliant)
    hvis ikke innes Exit Codes: 0 = Not Found (Compliant)
    
.Author
    Robwol

#>

try {
    # Install PSWindowsUpdate 
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