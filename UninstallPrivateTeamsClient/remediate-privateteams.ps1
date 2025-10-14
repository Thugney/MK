<#
 .Descriptions
    remediation skript for Intune Proactive Remediation
    skriptet avinstalleres private teams klient
   

.Author
    Robwol

#>

try{
    Get-AppxPackage -Name MicrosoftTeams -allusers | Remove-AppxPackage -ErrorAction stop
    Write-Host "Private MS Teams app successfully removed"
}catch{
    Write-Error "Error removing Microsoft Teams app"
}