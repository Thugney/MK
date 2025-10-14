<#
.SYNOPSIS
    Eksporterer enhetsnavn, primærbruker UPN (eller siste påloggede bruker) og avdeling fra en dynamisk Azure AD-enhetsgruppe til CSV.
.DESCRIPTION
    Skriptet bruker Microsoft Graph beta-endepunkt for å hente enheter fra en spesifisert gruppe, mapper til Intune managedDevices for primær UPN eller siste påloggede bruker, henter avdeling fra brukerobjektet, og eksporterer til CSV-fil.
.PARAMETER GroupId
    Object ID for den dynamiske gruppen (finn i Azure AD > Groups).
.PARAMETER OutputPath
    Sti til CSV-fil (f.eks. C:\Devices.csv).
.EXAMPLE
    .\Export-DevicesWithUPNAndDepartment.ps1 -GroupId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -OutputPath "C:\Devices.csv"
.NOTES
    Forfatter: robwol
    Versjon: 1.3
    Krever: Microsoft.Graph modul (versjon 2.0+), autentisering med Connect-MgGraph -Scopes "Device.Read.All,User.Read.All,DeviceManagementManagedDevices.Read.All".
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$GroupId,
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Autentiser mot Graph og bytt til beta-profil
Connect-MgGraph -Scopes "Device.Read.All,User.Read.All,DeviceManagementManagedDevices.Read.All"
Select-MgProfile -Name beta

# Hent gruppemedlemmer (enheter)
$devices = Get-MgGroupMember -GroupId $GroupId -All | Where-Object { $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.device' }

$results = @()

foreach ($device in $devices) {
    # Hent Entra enhetsdetaljer
    $deviceDetails = Get-MgDevice -DeviceId $device.Id -Property displayName, id, deviceId
    
    # Hent azureADDeviceId (som er deviceId i Entra)
    $azureADDeviceId = $deviceDetails.DeviceId
    
    # Hent Intune managedDevice basert på azureADDeviceId, inkludert usersLoggedOn
    $managedDevices = Get-MgDeviceManagementManagedDevice -Filter "azureADDeviceId eq '$azureADDeviceId'" -Property id, userPrincipalName, usersLoggedOn
    
    $primaryUPN = "Ingen bruker funnet"
    if ($managedDevices.Count -gt 0) {
        $managedDevice = $managedDevices[0]
        
        # Prøv primær UPN først
        if (-not [string]::IsNullOrEmpty($managedDevice.UserPrincipalName)) {
            $primaryUPN = $managedDevice.UserPrincipalName
        } elseif ($managedDevice.UsersLoggedOn.Count -gt 0) {
            # Fallback til siste påloggede bruker: sorter etter lastLogOnDateTime desc og ta første
            $latestLoggedOn = $managedDevice.UsersLoggedOn | Sort-Object -Property lastLogOnDateTime -Descending | Select-Object -First 1
            $userId = $latestLoggedOn.UserId
            try {
                $user = Get-MgUser -UserId $userId -Property userPrincipalName -ErrorAction Stop
                $primaryUPN = $user.UserPrincipalName - "UPN ikke tilgjengelig"
            } catch {
                $primaryUPN = "Feil ved henting av UPN: $($_.Exception.Message)"
            }
        }
    }
    
    # Hent avdeling fra bruker hvis UPN finnes
    $department = "Ikke satt"
    if (-not [string]::IsNullOrEmpty($primaryUPN) -and $primaryUPN -ne "Ingen bruker funnet") {
        try {
            $user = Get-MgUser -UserId $primaryUPN -Property department -ErrorAction Stop
            $department = $user.Department 
        } catch {
            $department = "Feil ved henting: $($_.Exception.Message)"
        }
    }
    
    $results += [PSCustomObject]@{
        DeviceName = $deviceDetails.DisplayName
        UPN = $primaryUPN
        Department = $department
    }
}

# Eksporter til CSV
$results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Output "Eksportert $($results.Count) enheter til $OutputPath"