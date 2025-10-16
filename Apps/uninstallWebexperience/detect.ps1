# Sjekk om Windows Web Experience Pack er installert via Winget 

try {
    # Kjør winget list for å sjekke pakken (ID: 9MSSGKG348SP)
    $output = & winget list --id 9MSSGKG348SP --exact --accept-source-agreements
    if ($output -match "9MSSGKG348SP") {
        Write-Output "Windows Web Experience Pack er installert - trenger remediering"
        exit 1
    } else {
        Write-Output "Windows Web Experience Pack er ikke installert"
        exit 0
    }
} catch {
    Write-Output "Feil under deteksjon: $_ - antar pakken er ikke installert"
    exit 0
}