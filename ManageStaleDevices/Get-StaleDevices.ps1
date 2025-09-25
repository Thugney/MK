<#
.SYNOPSIS
    Retrieves stale devices from Entra ID based on last activity and OS type, and exports to CSV.

.PARAMETER OSType
    The operating system type to filter (e.g., "Windows"). Optional.

.PARAMETER LastActivityDays
    Number of days since last activity to consider a device stale. Required.

.PARAMETER ExportPath
    Path to export the CSV file. Default: "stale_devices.csv".

.EXAMPLE
    .\Get-StaleDevices.ps1 -LastActivityDays 90 -OSType "Windows" -ExportPath "C:\Temp\stale_devices.csv"
#>

param (
    [string]$OSType,
    [Parameter(Mandatory=$true)]
    [int]$LastActivityDays,
    [string]$ExportPath = "stale_devices.csv"
)

try {
    # Connect to Microsoft Graph with required scopes
    Connect-MgGraph -Scopes "Device.Read.All" -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure you have the Microsoft.Graph module installed and proper permissions. Error: $_"
    exit
}

try {
    # Calculate the cutoff date in UTC format for filtering
    $cutoffDate = (Get-Date).AddDays(-$LastActivityDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Build the filter string
    $filter = "approximateLastSignInDateTime le $cutoffDate"
    if ($OSType) {
        $filter += " and operatingSystem eq '$OSType'"
    }

    # Retrieve devices using server-side filter for efficiency
    $devices = Get-MgDevice -Filter $filter -All -ErrorAction Stop

    if ($devices.Count -eq 0) {
        Write-Host "No stale devices found matching the criteria."
        exit
    }

    # Select relevant properties and export to CSV
    $devices | Select-Object Id, DeviceId, DisplayName, OperatingSystem, ApproximateLastSignInDateTime, AccountEnabled |
        Export-Csv -Path $ExportPath -NoTypeInformation -ErrorAction Stop

    Write-Host "Exported $($devices.Count) stale devices to $ExportPath."
} catch {
    Write-Error "Error retrieving or exporting devices. Error: $_"
}