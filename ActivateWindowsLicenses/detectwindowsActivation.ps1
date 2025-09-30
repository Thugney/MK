<#
    .Descriptions
        detection skriptet sjekkr aktivering status på Windows OS
        1 - Hvis status er aktivt skriptet stopper = (Compliant)
        2 - Hvis status på Windows lisens ikke er aktivt, trigger remediation (Not compliant)
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation

    .Version
        Pilot

#>

try {
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' AND PartialProductKey IS NOT NULL"
    if ($license -and $license.LicenseStatus -eq 1) {
        Write-Output "Windows is activated"
        exit 0
    } else {
        Write-Output "Windows is NOT activated"
        exit 1
    }
}
catch {
    # Fallback check using slmgr.vbs (read-only)
    $result = & cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr
    if ($result -match "permanently activated") {
        Write-Output "Windows is activated (via slmgr fallback)"
        exit 0
    } else {
        Write-Output "Windows is NOT activated"
        exit 1
    }
}