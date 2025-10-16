<#
.SYNOPSIS
    .Descriptions
        remediate skriptet restarter sppsvc
        1 - bruker slmgr /ato for å forsøke å aktivere lisensen
        2 - stoppr/restarter sppsvc
        2 - bruker slmgr /dli for verifisering
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
        
    .Version
        Pilot

#>

$LogPath = "$env:ProgramData\WindowsActivationLogs"
$LogFile = "$LogPath\Remediation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }

function Log-Message {
    param ([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"
    Add-Content -Path $LogFile -Value $logEntry -Force
    Write-Output $logEntry
}

Log-Message "Starting Windows activation remediation"

try {
    $osEdition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID
    Log-Message "Detected Windows Edition: $osEdition"

    if ($osEdition -like "*Eval*") {
        Log-Message "Evaluation edition detected - remediation skipped (requires edition conversion, e.g., via DISM or key install). Flag for manual review." "WARN"
        exit 1
    }

    # Check internet connectivity (required for online activation)
    if (-not (Test-Connection -ComputerName www.microsoft.com -Count 1 -Quiet)) {
        throw "No internet connectivity detected. Activation requires online access."
    }
    Log-Message "Internet connectivity confirmed"

    # Restart sppsvc if running
    $sppsvc = Get-Service -Name "sppsvc" -ErrorAction SilentlyContinue
    if ($sppsvc -and $sppsvc.Status -eq "Running") {
        Stop-Service -Name "sppsvc" -Force -ErrorAction Stop
        Log-Message "Stopped sppsvc service"
        Start-Sleep -Seconds 5
    }
    Start-Service -Name "sppsvc" -ErrorAction Stop
    Log-Message "Started sppsvc service"
    Start-Sleep -Seconds 10

    # Attempt activation
    Log-Message "Attempting activation using slmgr.vbs /ato"
    $atoResult = cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ato
    Log-Message "slmgr /ato output: $atoResult"

    Start-Sleep -Seconds 15

    # Verify with slmgr /dli
    $verifyResult = cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli
    Log-Message "slmgr /dli verification output: $verifyResult"
    if ($verifyResult -match "Licensed" -and $verifyResult -notmatch "Eval" -and $verifyResult -notmatch "EVAL channel" -and $verifyResult -notmatch "Timebased activation expiration.*\d+ minute") {
        Log-Message "Activation successful (verified via /dli, no eval or expiration)"
        exit 0
    } else {
        throw "Activation failed or eval/expiration detected (not fully Licensed per /dli)"
    }
} catch {
    Log-Message "Error during remediation: $($_.Exception.Message)" "ERROR"
    exit 1
}