<#
.SYNOPSIS
    Removes devices from Intune and Windows Autopilot using an imported CSV file.

.PARAMETER InputPath
    Path to the CSV file exported from Get-StaleDevices.ps1. Default: "stale_devices.csv".

.EXAMPLE
    .\Remove-AutopilotDevices.ps1 -InputPath "C:\Temp\stale_devices.csv"
#>

param (
    [string]$InputPath = "C:\Users\robwol\OneDrive - Modum kommune\Documents\Intune\24-09\exportDevice_noAutoppilot_2025-9-24.csv"
)

try {
    # Connect to Microsoft Graph with required scopes
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementServiceConfig.ReadWrite.All" -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure you have the Microsoft.Graph module installed and proper permissions. Error: $_"
    exit
}

try {
    # Import the CSV file
    $devices = Import-Csv -Path $InputPath -ErrorAction Stop
    if ($devices.Count -eq 0) {
        Write-Host "No devices found in the CSV file."
        exit
    }

    foreach ($device in $devices) {
        $azureAdDeviceId = $device.DeviceId
        try {
            # Check and remove from Intune (if managed)
            $managedDevice = Get-MgDeviceManagementManagedDevice -Filter "azureADDeviceId eq '$azureAdDeviceId'" -ErrorAction SilentlyContinue
            if ($managedDevice) {
                Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $managedDevice.Id -ErrorAction Stop
                Write-Host "Removed from Intune: $($device.DisplayName) (Azure AD Device ID: $azureAdDeviceId)"
                Start-Sleep -Seconds 10  # Allow time for propagation
            } else {
                Write-Host "No Intune record found for $($device.DisplayName) (Azure AD Device ID: $azureAdDeviceId). Skipping."
            }

            # Check and remove from Autopilot
            $autopilotDevice = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -Filter "azureActiveDirectoryDeviceId eq '$azureAdDeviceId'" -ErrorAction SilentlyContinue
            if ($autopilotDevice) {
                Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity -WindowsAutopilotDeviceIdentityId $autopilotDevice.Id -ErrorAction Stop
                Write-Host "Removed from Autopilot: $($device.DisplayName) (Azure AD Device ID: $azureAdDeviceId)"
                Start-Sleep -Seconds 10  # Allow time for propagation
            } else {
                Write-Host "No Autopilot record found for $($device.DisplayName) (Azure AD Device ID: $azureAdDeviceId). Skipping."
            }
        } catch {
            Write-Error "Failed to process $($device.DisplayName) (Azure AD Device ID: $azureAdDeviceId). Error: $_"
        }
    }

    Write-Host "Processed $($devices.Count) devices."
} catch {
    Write-Error "Error importing CSV or processing devices. Error: $_"
}