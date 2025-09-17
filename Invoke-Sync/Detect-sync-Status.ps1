# Create variable for the time of the last Intune sync.
$PushInfo = Get-ScheduledTask -TaskName Modum IT M365 | Get-ScheduledTaskInfo
$LastPush = $PushInfo.LastRunTime
$CurrentTime=(GET-DATE)

# tidsforskjellen mellom gjeldende dato/klokkeslett og datoen som er lagret i variabelen.
$TimeDiff = New-TimeSpan -Start $LastPush -End $CurrentTime

# om tidsforskjellen mellom siste synkronisering og gjeldende tid er mindre eller større enn 2 dager
if ($TimeDiff.Days -gt 2) {
    # Tidsforskjellen er mer enn 2 dager
    Write-Host "Last Sync was more than 2 days ago"
    Exit 1
} else {
    # TTidsforskjellen er mer enn 2 dager
    Write-Host "Sync Complete"
    Exit 0
}