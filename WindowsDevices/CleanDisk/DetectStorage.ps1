<#
.SYNOPSIS
    Sjekker ledig diskplass på C-disken og rapporterer compliance-status.

.DESCRIPTION
    Detection-skript for Intune Remediations.
    Bruker både prosentbasert og absolutt terskel for å identifisere enheter med lite diskplass.
    - Under 10% ledig ELLER under 15GB = Ikke compliant
    - Ellers = Compliant
    Fungerer godt for enheter med 100-250GB disk der brukerdata lagres i OneDrive.

.EXAMPLE
    .\Detect-DiskSpace.ps1

.NOTES
    Author: robwol
    Version: 1.0
    Kjøres i SYSTEM-kontekst via Intune Remediations
    Logging: Ingen - bruker Intune output
#>

# Terskelverdier - juster etter behov
$MinFreeSpaceGB = 15          # Minimum GB ledig
$MinFreeSpacePercent = 10     # Minimum prosent ledig

try {
    # Hent disk-info via WMI (mer pålitelig enn Get-PSDrive)
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    
    if (-not $disk) {
        Write-Output "FEIL: Kunne ikke hente disk-informasjon"
        exit 1
    }
    
    # Beregn verdier
    $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
    $freeSpacePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
    
    # Evaluer compliance
    $isCompliant = ($freeSpaceGB -ge $MinFreeSpaceGB) -and ($freeSpacePercent -ge $MinFreeSpacePercent)
    
    if ($isCompliant) {
        Write-Output "Compliant: $freeSpaceGB GB ledig ($freeSpacePercent%) av $totalSpaceGB GB"
        exit 0
    }
    else {
        Write-Output "Non-Compliant: $freeSpaceGB GB ledig ($freeSpacePercent%) av $totalSpaceGB GB | Terskel: ${MinFreeSpaceGB}GB eller ${MinFreeSpacePercent}%"
        exit 1
    }
}
catch {
    Write-Output "FEIL: $($_.Exception.Message)"
    exit 1
}
