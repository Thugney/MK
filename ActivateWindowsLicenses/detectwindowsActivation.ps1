<#
    .Descriptions
        detection skriptet sjekker om Windows lisens er aktivert
        1 - Hvis ikke er aktivert (Not compliant) trigger remediation
        2 - Hvis status er aktivert, (compliant) trenges ikke remediation
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
    .Version
        Pilot

#>

$LogPath = "$env:ProgramData\WindowsActivationLogs"
$LogFile = "$LogPath\Detection_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }

function Log-Message {
    param ([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"
    Add-Content -Path $LogFile -Value $logEntry -Force
    Write-Output $logEntry
}

Log-Message "Starting Windows activation detection"

try {
    $osEdition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID
    Log-Message "Detected Windows Edition: $osEdition"

    $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' AND PartialProductKey IS NOT NULL" -ErrorAction Stop
    if ($license) {
        Log-Message "License found: Description = $($license.Description), Status = $($license.LicenseStatus)"
        if ($license.LicenseStatus -eq 1) {
            Log-Message "Windows is activated (LicenseStatus = 1)"
            exit 0
        } else {
            Log-Message "Windows is NOT activated (LicenseStatus = $($license.LicenseStatus))"
            exit 1
        }
    } else {
        Log-Message "No license object found with PartialProductKey"
        exit 1
    }
} catch {
    Log-Message "Primary check failed: $($_.Exception.Message)" "ERROR"
    try {
        $slmgrResult = cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli
        Log-Message "slmgr /dli output: $slmgrResult"
        if ($slmgrResult -match "Licensed") {
            Log-Message "Windows is activated (via slmgr /dli fallback)"
            exit 0
        } else {
            Log-Message "Windows is NOT activated (via slmgr /dli fallback)"
            exit 1
        }
    } catch {
        Log-Message "Fallback check failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}