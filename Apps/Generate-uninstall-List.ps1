<#
.SYNOPSIS
Genererer install-liste (tom for nå).
new-apps-install-list.ps1 (Detection Only – Keep Empty)
#>

[CmdletBinding()]
param()

$BasePath = "C:\MK-LogFiles\Winget"
$File = "$BasePath\InstallList.json"
$Version = "1.0"  # Behold uendret

$Apps = @()  # Ingen installasjoner

if (-not (Test-Path $BasePath)) { New-Item -ItemType Directory -Path $BasePath -Force }

$Data = @{ Version = $Version; Apps = $Apps }

$Update = $true
if (Test-Path $File) {
    $Current = Get-Content $File | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($Current.Version -eq $Version) { $Update = $false }
}

if ($Update) {
    $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $File -Encoding UTF8 -Force
    Write-Host "Install-liste v$Version"
} else {
    Write-Host "Ingen endring"
}

exit 0