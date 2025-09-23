# Windows License Activation Remediation Script
# remediation for Education and Enterprise editions
 
try {
    Write-Output "Starting Windows activation remediation"
    
    # Restart licensing service
    Write-Output "Restarting licensing service"
    Stop-Service -Name "sppsvc" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Start-Service -Name "sppsvc" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
    
    # Attempt activation
    Write-Output "Attempting activation"
    $result = & cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ato 2>&1
    Start-Sleep -Seconds 15
    
    # Check if successful
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' AND PartialProductKey IS NOT NULL"
    
    if ($license -and $license.LicenseStatus -eq 1) {
        Write-Output "Activation successful"
        exit 0
    } else {
        Write-Output "Activation failed"
        exit 1
    }
}
catch {
    Write-Output "Error during remediation: $($_.Exception.Message)"
    exit 1
}