try {
    Get-ScheduledTask | ? {$_.TaskName -eq 'Modum IT M365 '} | Start-ScheduledTask
    Exit 0
}
catch {
    Write-Error $_
    Exit 1
}