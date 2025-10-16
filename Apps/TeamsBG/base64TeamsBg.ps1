<#
    Forfatter: robwol
    Beskrivelse: Hjelpeskript for å kode Teams-bakgrunnsbilder til base64-strenger for inkludering i Intune-remedieringsskript.
    Opprettet: 14. oktober 2025
#>

$ErrorActionPreference = "Stop"
$ImagePaths = @(
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_vei sommer.png"
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_vann sommer.png"
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_solnedgang vinter.png"
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_hoppsenter vinter.png"
    "C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_gamlegaarden tulipaner.png"
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_i skogen sommer.png"
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_solnedgang vinter.png"
    #"C:\Users\robwol\Documents\TeamsBG\mk_teamsbakgrunn_vann sommer.png"
)

$ImageNames = @(
    "mk_teamsbakgrunn_gamlegaarden tulipaner.png",
    "mk_teamsbakgrunn_foss.png",
    "mk_teamsbakgrunn_blå bølge.png",
    "mk_teamsbakgrunn_hoppsenter vinter.png",
    "mk_teamsbakgrunn_vei sommer.png",
    "mk_teamsbakgrunn_i skogen sommer.png",
    "mk_teamsbakgrunn_solnedgang vinter.png",
    "mk_teamsbakgrunn_vann sommer.png"
)

for ($i = 0; $i -lt $ImagePaths.Count; $i++) {
    $path = $ImagePaths[$i]
    $name = $ImageNames[$i]
    if (Test-Path -Path $path) {
        $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        Write-Output "`$$name_Base64 = '$base64'"
    } else {
        Write-Error "Bilde ikke funnet: $path"
    }
}