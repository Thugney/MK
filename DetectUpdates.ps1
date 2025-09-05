$updateListUri = "https://raw.githubusercontent.com/thugney/MK/main/AppsList.txt"
$localPath = "C:\ProgramData\AppList\update-apps.txt"

# Download the list
try {
    Invoke-WebRequest -Uri $updateListUri -OutFile $localPath -UseBasicParsing
    $apps_to_update = Get-Content $localPath | Select-Object -Skip 1  # Skip version line
} catch {
    Write-Error "Failed to download app list"
    exit 0
}

$Winget = Get-ChildItem -Path (Join-Path -Path (Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps") -ChildPath "Microsoft.DesktopAppInstaller*_x64*\winget.exe")

$available_updates = & $winget upgrade
$updates_needed = $false

foreach ($app in $apps_to_update) {
    if ($available_updates -like "* $app *") {
        $updates_needed = $true
        break
    }
}

if ($updates_needed) {
    exit 1
} else {
    exit 0
}