# Fjern Windows Web Experience Pack via Winget - forfatter: 'robwol'

# Definer loggsti
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\RemoveWebExperiencePack.log"

# Start logging
Start-Transcript -Path $LogPath -Append

try {
    # Stopp relaterte prosesser for å unngå låser (f.eks. Widgets.exe)
    Write-Host "Stopper Widgets-prosessen "
    Stop-Process -Name "Widgets" -Force -ErrorAction SilentlyContinue

    # Fjern pakken via Winget (ID: 9MSSGKG348SP)
    Write-Host "Fjerner Windows Web Experience Pack"
    & winget uninstall --id 9MSSGKG348SP --silent 

    Write-Host "Done!"
} catch {
    Write-Warning "Feil under avinstallering: $_"
} finally {
    # Stopp logging
    Stop-Transcript
}