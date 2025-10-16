# Check last Intune sync time
$PushInfo = Get-ScheduledTask -TaskName "PushLaunch" -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo
$LastPush = $PushInfo?.LastRunTime
$CurrentTime = Get-Date

if (-not $PushInfo -or -not $LastPush) {
    Write-Host "Task 'PushLaunch' not found or no last run time recorded. Attempting remediation..."
    $NeedsRemediation = $true
} else {
    $TimeDiff = New-TimeSpan -Start $LastPush -End $CurrentTime
    if ($TimeDiff.Days -gt 2) {
        Write-Host "Last Sync was more than 2 days ago. Attempting remediation..."
        $NeedsRemediation = $true
    } else {
        Write-Host "Sync Complete"
        Exit 0
    }
}
