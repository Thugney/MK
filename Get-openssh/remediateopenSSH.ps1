try {
    Write-Output "Starting OpenSSH uninstall"

    # Uninstall Client if installed
    $client = Get-WindowsCapability -Online -Name OpenSSH.Client* | Where-Object { $_.State -eq 'Installed' }
    if ($client) {
        Write-Output "Uninstalling OpenSSH Client"
        Remove-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction Stop
    }

    # Uninstall Server if installed
    $server = Get-WindowsCapability -Online -Name OpenSSH.Server* | Where-Object { $_.State -eq 'Installed' }
    if ($server) {
        Write-Output "Uninstalling OpenSSH Server"
        Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
    }

    Write-Output "Uninstall completed"
    exit 0
}
catch {
    Write-Output "Error during uninstall: $($_.Exception.Message)"
    exit 1
}