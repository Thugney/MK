<#
 .Descriptions
    Detection skript for Intune Proactive Remediation
    skriptet sjekkr om private teams klient er installert
    Hvis finnes  1 = Found (Non-Compliant)
    hvis ikke innes Exit Codes: 0 = Not Found (Compliant)
    
.Author
    Robwol

#>

if ($null -eq (Get-AppxPackage -Name MicrosoftTeams -allusers)) {
	Write-Host "Private MS Teams client is not installed"
	exit 0
} Else {
	Write-Host "Private MS Teams client is installed"
	Exit 1
}