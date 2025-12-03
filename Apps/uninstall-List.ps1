<#
.SYNOPSIS
Genererer uninstall-liste.
new-apps-uninstall-list.ps1 (Detection Only)
#>

[CmdletBinding()]
param()

$BasePath = "C:\MK-LogFiles\Winget"
$File = "$BasePath\UninstallList.json"
$Version = "1.1"  # BUMPED

$Apps = @(
    @{ Id = "Google.Chrome" }
    @{ Id = "VideoLAN.VLC" }
)

if (-not (Test-Path $BasePath)) { New-Item -ItemType Directory -Path $BasePath -Force }

$Data = @{ Version = $Version; Apps = $Apps }

$Update = $true
if (Test-Path $File) {
    $Current = Get-Content $File | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($Current.Version -eq $Version) { $Update = $false }
}

if ($Update) {
    $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $File -Encoding UTF8 -Force
    Write-Host "Uninstall-liste oppdatert v$Version"
} else {
    Write-Host "Ingen endring"
}

exit 0