try {
    $clientInstalled = Get-WindowsCapability -Online -Name OpenSSH.Client* | Where-Object { $_.State -eq 'Installed' }
    $serverInstalled = Get-WindowsCapability -Online -Name OpenSSH.Server* | Where-Object { $_.State -eq 'Installed' }

    if ($clientInstalled -or $serverInstalled) {
        Write-Output "OpenSSH detected - remediation needed"
        exit 1
    } else {
        Write-Output "No OpenSSH installed - compliant"
        exit 0
    }
}
catch {
    Write-Output "Error in detection: $($_.Exception.Message)"
    exit 1
}