$TagPath = "$env:ProgramData\Microsoft\RemoveW10Bloatware\RemoveW10Bloatware.ps1.tag"
if (-not (Test-Path $TagPath)) {
    Write-Output "Bloatware removal not detected"
    exit 1
} else {
    Write-Output "Bloatware already removed"
    exit 0
}