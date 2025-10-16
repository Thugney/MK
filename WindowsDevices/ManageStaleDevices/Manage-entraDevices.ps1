<#
.SYNOPSIS
    Disables or removes devices in Entra ID using an imported CSV file.

.PARAMETER InputPath
    Path to the CSV file. Default: "stale_devices.csv".

.PARAMETER Action
    Action to perform: "Disable" or "Remove". Required.

.PARAMETER IdColumn
    Column name for the Entra ID object ID. Default: Attempts "Id" or "objectId".

.PARAMETER DisplayNameColumn
    Column name for the display name (for logging). Default: "DisplayName".

.PARAMETER LogPath
    Path for optional log file. Default: None.

.EXAMPLE
    .\Manage-EntraDevices.ps1 -InputPath "C:\Temp\your_custom.csv" -Action "Disable" -IdColumn "objectId" -DisplayNameColumn "DisplayName"
#>

param (
    [string]$InputPath = "C:\Users\robwol\OneDrive - Modum kommune\Documents\Intune\24-09\exportDevice_noAutoppilot_2025-9-24.csv",
    [Parameter(Mandatory=$true)]
    [ValidateSet("Disable", "Remove")]
    [string]$Action,
    [string]$IdColumn,
    [string]$DisplayNameColumn = "DisplayName",
    [string]$LogPath
)

function Write-Log {
    param ([string]$Message)
    if ($LogPath) {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    }
    Write-Host $Message
}

try {
    # Connect to Microsoft Graph with required scopes
    Connect-MgGraph -Scopes "Device.ReadWrite.All" -ErrorAction Stop
    Write-Log "Connected to Microsoft Graph successfully."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure you have the Microsoft.Graph module installed and proper permissions. Error: $_"
    exit
}

try {
    # Import the CSV file
    $devices = Import-Csv -Path $InputPath -ErrorAction Stop
    if ($devices.Count -eq 0) {
        Write-Log "No devices found in the CSV file."
        exit
    }

    $processedCount = 0
    $skippedCount = 0

    # Determine the ID column name (user-specified or auto-detect)
    if (-not $IdColumn) {
        $IdColumn = if ($devices[0].PSObject.Properties.Name -contains "Id") { "Id" } 
                    elseif ($devices[0].PSObject.Properties.Name -contains "objectId") { "objectId" } 
                    else { throw "CSV missing required ID column. Specify -IdColumn (e.g., 'objectId')." }
    }

    # Check if specified columns exist
    if ($devices[0].PSObject.Properties.Name -notcontains $IdColumn) {
        throw "Specified IdColumn '$IdColumn' not found in CSV headers."
    }
    if ($devices[0].PSObject.Properties.Name -notcontains $DisplayNameColumn) {
        Write-Warning "DisplayNameColumn '$DisplayNameColumn' not found; using empty string for logging."
        $DisplayNameColumn = $null  # Fallback to avoid errors
    }

    foreach ($device in $devices) {
        $deviceId = $device.$IdColumn
        $displayName = if ($DisplayNameColumn) { $device.$DisplayNameColumn } else { "" }

        if ([string]::IsNullOrWhiteSpace($deviceId)) {
            Write-Warning "Skipping invalid row: Empty Device ID (DisplayName: $displayName). Check CSV for blank entries."
            Write-Log "Skipped: Empty Device ID (DisplayName: $displayName)."
            $skippedCount++
            continue
        }

        try {
            if ($Action -eq "Disable") {
                Update-MgDevice -DeviceId $deviceId -AccountEnabled $false -ErrorAction Stop
                Write-Log "Disabled device: $displayName (ID: $deviceId)"
            } elseif ($Action -eq "Remove") {
                Remove-MgDevice -DeviceId $deviceId -ErrorAction Stop
                Write-Log "Removed device: $displayName (ID: $deviceId)"
            }
            $processedCount++
        } catch {
            Write-Error "Failed to $Action device $displayName (ID: $deviceId). Error: $_"
            Write-Log "Error: Failed to $Action $displayName (ID: $deviceId). $_"
        }
    }

    Write-Log "Processed $processedCount devices. Skipped $skippedCount invalid rows."
} catch {
    Write-Error "Error importing CSV or processing devices. Error: $_"
    Write-Log "Script error: $_"
}