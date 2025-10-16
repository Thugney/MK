<#
.SYNOPSIS
    Retrieves serial numbers from Intune Data Warehouse for devices (including deleted ones) using Intune or Azure AD device ID.

.PARAMETER WarehouseUrl
    The custom feed URL from Intune admin center (required).

.PARAMETER ClientId
    The Azure app registration client ID (required).

.PARAMETER DeviceIds
    Array of Intune device IDs or Azure AD device IDs (required).

.PARAMETER IdType
    'Intune' for managedDeviceId or 'AzureAD' for azureADDeviceId. Default: 'AzureAD'.

.PARAMETER ExportPath
    Path to export CSV if multiple IDs. Default: "serial_numbers.csv".

.EXAMPLE
    .\Get-SerialFromDataWarehouse.ps1 -WarehouseUrl "https://fef.msun02.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=v1.0" -ClientId "your-client-id" -DeviceIds @("guid1", "guid2") -IdType "AzureAD" -ExportPath "C:\Temp\serials.csv"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$WarehouseUrl,
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    [Parameter(Mandatory=$true)]
    [string[]]$DeviceIds,
    [ValidateSet("Intune", "AzureAD")]
    [string]$IdType = "AzureAD",
    [string]$ExportPath = "serial_numbers.csv"
)

# Function to get access token (adapted from standard approach)
function Get-DataWarehouseToken {
    param (
        [string]$ClientId,
        [string]$RedirectUri = "https://login.live.com/oauth20_desktop.srf"
    )
    try {
        # Load ADAL assembly (install via NuGet if needed)
        $adalPath = "$env:USERPROFILE\.nuget\packages\microsoft.identitymodel.clients.activedirectory\3.19.8\lib\net45"  # Adjust version if needed
        if (-not (Test-Path "$adalPath\Microsoft.IdentityModel.Clients.ActiveDirectory.dll")) {
            Write-Error "ADAL DLL not found. Install via: Install-Package Microsoft.IdentityModel.Clients.ActiveDirectory -Version 3.19.8"
            exit
        }
        Add-Type -Path "$adalPath\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"

        $authority = "https://login.microsoft.com/common"
        $resource = "https://api.manage.microsoft.com/"
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
        $platformParams = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
        $authResult = $authContext.AcquireTokenAsync($resource, $ClientId, [Uri]$RedirectUri, $platformParams).Result
        return $authResult.AccessToken
    } catch {
        Write-Error "Failed to get access token. Ensure app permissions and login. Error: $_"
        exit
    }
}

try {
    $token = Get-DataWarehouseToken -ClientId $ClientId
    Write-Host "Access token acquired successfully."

    $results = @()
    foreach ($id in $DeviceIds) {
        try {
            $filter = if ($IdType -eq "Intune") { "deviceId eq '$id'" } else { "azureADDeviceId eq '$id'" }
            $uri = "$WarehouseUrl/devices?`$filter=$filter"

            $headers = @{
                "Authorization" = "Bearer $token"
                "Accept" = "application/json"
            }

            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
            if ($response.value.Count -eq 0) {
                Write-Host "No record found for ID $id."
                continue
            }

            $device = $response.value[0]
            $results += [PSCustomObject]@{
                DeviceId = $id
                SerialNumber = $device.serialNumber
                DeviceName = $device.deviceName
                IsDeleted = $device.isDeleted
                AzureADDeviceId = $device.azureADDeviceId
            }
            Write-Host "Retrieved serial $($device.serialNumber) for ID $id (Deleted: $($device.isDeleted))."
        } catch {
            Write-Error "Failed to query for ID $id. Error: $_"
        }
    }

    if ($results.Count -gt 0 -and $DeviceIds.Count -gt 1) {
        $results | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "Exported results to $ExportPath."
    } elseif ($results.Count -eq 0) {
        Write-Host "No serial numbers retrieved."
    }
} catch {
    Write-Error "Script execution failed. Error: $_"
}