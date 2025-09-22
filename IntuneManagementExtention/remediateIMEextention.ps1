<#
.SYNOPSIS
Reinstall/Restart Intune Management Extension.
#>

$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogPath\IMERemediation_$(Get-Date -Format 'yyyyMMdd').log"
if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
Add-Content -Path $LogFile -Value "$(Get-Date) - Starting IME remediation" -Force
try {
    # Stop IME if running
    $imeService = Get-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue
    if ($imeService -and $imeService.Status -eq "Running") {
        Stop-Service -Name "IntuneManagementExtension" -Force -ErrorAction SilentlyContinue
        Add-Content -Path $LogFile -Value "$(Get-Date) - Stopped IME service" -Force
    }

    # Uninstall if present
    $imeUninstall = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*Intune*Management*Extension*" }
    if ($imeUninstall) {
        $productCode = $imeUninstall.PSChildName
        Start-Process "msiexec.exe" -ArgumentList "/x {$productCode} /quiet /norestart" -Wait -NoNewWindow
        Add-Content -Path $LogFile -Value "$(Get-Date) - Uninstalled existing IME" -Force
    }

    # Download and install latest IME
    $imeUrl = "https://go.microsoft.com/fwlink/?linkid=2204783"
    $imePath = "$env:TEMP\IntuneManagementExtension.msi"
    Invoke-WebRequest -Uri $imeUrl -OutFile $imePath -ErrorAction Stop
    Start-Process "msiexec.exe" -ArgumentList "/i `"$imePath`" /quiet /norestart" -Wait -NoNewWindow
    Remove-Item $imePath -Force -ErrorAction SilentlyContinue
    Add-Content -Path $LogFile -Value "$(Get-Date) - Installed IME" -Force

    # Start service
    Start-Service -Name "IntuneManagementExtension" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10

    # Optional: Trigger scheduled task for sync (if exists)
    try {
        Start-ScheduledTask -TaskName "PushLaunch" -TaskPath "\Microsoft\Windows\EnterpriseMgmt\" -ErrorAction SilentlyContinue
        Add-Content -Path $LogFile -Value "$(Get-Date) - Triggered PushLaunch scheduled task" -Force
    } catch {}

    Add-Content -Path $LogFile -Value "$(Get-Date) - Started IME service and forced sync" -Force
    Write-Output "Success: IME reinstalled and synced."
    exit 0
} catch {
    Add-Content -Path $LogFile -Value "$(Get-Date) - Error: $($_.Exception.Message)" -Force
    Write-Output "Failed: $($_.Exception.Message)"
    exit 1
}
