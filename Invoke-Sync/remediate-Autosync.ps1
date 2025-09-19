try {
    $Task = Get-ScheduledTask | Where-Object { $_.TaskName -eq "Modum IT M365" }
    if ($Task) {
        Start-ScheduledTask -TaskName "Modum IT M365"
        Write-Host "Task 'Modum IT M365' started successfully."
        Exit 0
    } else {
        Write-Error "Task 'Modum IT M365' not found."
        Exit 1
    }
}
catch {
    Write-Error "Failed to start task: $_"
    Exit 1
}