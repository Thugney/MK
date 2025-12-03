<#
.SYNOPSIS
Fjerner apper fra UninstallList.json.
winget-uninstall_apps.ps1 (Detection + Remediation – Fixed)
#>

[CmdletBinding(SupportsShouldProcess)]
param()

$BasePath = "C:\MK-LogFiles\Winget"
$ListFile = "$BasePath\UninstallList.json"
$LogDir = "$BasePath\Logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force }

if (-not (Test-Path $ListFile)) { Write-Host "Mangler UninstallList.json"; exit 1 }
$List = Get-Content $ListFile | ConvertFrom-Json

$NeedsRemediation = $false

foreach ($App in $List.Apps) {
    $SafeId = $App.Id -replace '\.', '_'
    $LogFile = "$LogDir\$SafeId`_uninstall.log"
    $Installed = winget list --id $App.Id --exact  --source winget

    if ($Installed) {
        $NeedsRemediation = $true
        if ($PSCmdlet.ShouldProcess($App.Id, "Uninstall")) {
            winget uninstall --id $App.Id --force --silent -log $LogFile
        }
    }
}

if ($NeedsRemediation) { Write-Host "Uninstall kjørt"; exit 1 } else { Write-Host "Ingen apper å fjerne"; exit 0 }