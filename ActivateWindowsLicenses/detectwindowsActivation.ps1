# Windows License Activation Detection Script
# detection for Education and Enterprise editions
 
try {
    # Check activation status
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' AND PartialProductKey IS NOT NULL"
    
    if ($license -and $license.LicenseStatus -eq 1) {
        Write-Output "Windows is activated"
        exit 0
    } else {
        Write-Output "Windows is NOT activated - remediation needed"
        exit 1
    }
}
catch {
    Write-Output "Error checking activation status"
    exit 1
}