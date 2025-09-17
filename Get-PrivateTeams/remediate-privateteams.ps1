try{
    Get-AppxPackage -Name MicrosoftTeams -allusers | Remove-AppxPackage -ErrorAction stop
    Write-Host "Private MS Teams app successfully removed"
}catch{
    Write-Error "Error removing Microsoft Teams app"
}