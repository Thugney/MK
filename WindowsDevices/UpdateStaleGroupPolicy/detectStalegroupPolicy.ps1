#detectStaleGroupPolicy

try {
    $gpResult = [datetime]::FromFileTime(([Int64] ((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}").startTimeHi) -shl 32) -bor ((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}").startTimeLo))
    $lastGPUpdateDate = Get-Date ($gpResult[0])
    [int]$lastGPUpdateDays = (New-TimeSpan -Start $lastGPUpdateDate -End (Get-Date)).Days
        
    if ($lastGPUpdateDays -gt 2){
        #Exit 1 for Intune. We want it to be within the last 2 days "Compliant" to remediate in SCCM
        Write-Host "Compliant"
        exit 1
    }
    else {
        #Exit 0 for Intune and "No_Compliant" for SCCM, only remediate "Compliant"
        Write-Host "No_Compliant"
        exit 0
    }
}
catch {
    $errMsg = $_.Exception.Message
    return $errMsg
    exit 1
}