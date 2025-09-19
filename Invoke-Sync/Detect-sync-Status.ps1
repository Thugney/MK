# Create variable for the time of the last Intune sync.
$PushInfo = Get-ScheduledTask -TaskName "Modum IT M365" | Get-ScheduledTaskInfo
$LastPush = $PushInfo.LastRunTime
$CurrentTime = Get-Date

# Handle case where task is missing or has no last run time (treat as non-compliant)
if (-not $PushInfo -or -not $LastPush) {
    Write-Host "Task 'Modum IT M365' not found or no last run time recorded."
    Exit 1
}

# Calculate the time difference between current date/time and the stored date.
$TimeDiff = New-TimeSpan -Start $LastPush -End $CurrentTime

# If the time difference between last sync and current time is more than 2 days
if ($TimeDiff.Days -gt 2) {
    # Time difference is more than 2 days
    Write-Host "Last Sync was more than 2 days ago"
    Exit 1
} else {
    # Time difference is 2 days or less
    Write-Host "Sync Complete"
    Exit 0
}