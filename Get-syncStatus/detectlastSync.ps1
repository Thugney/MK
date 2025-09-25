# Check last Intune sync time
$PushInfo = (Get-ScheduledTask -TaskName 'PushLaunch' | Get-ScheduledTaskInfo)[0]
$LastPush = $PushInfo.LastRunTime
$CurrentTime=(GET-DATE)

$TimeDiff = New-TimeSpan -Start $LastPush -End $CurrentTime

if ($TimeDiff.Days -gt 2) {
    # The time difference is more than 2 days
    Write-Host "not-compliant"
    Exit 1
} else {
    # The time difference is less than 2 days
    Write-Host "compliant"
    Exit 0
}

