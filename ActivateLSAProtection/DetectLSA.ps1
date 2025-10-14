<#
    .Descriptions
        detect skriptet sjekkr statu på LSA  status 
        1 - Hvis status er aktivt skriptet stopper = (Compliant)
        2 - Hvis status på LSA ikke er aktivt, trigger remediation (Not compliant)
    .Author
        robwol
    .Usage 
        skriptet rulles som intune proactive - lastes opp i intune skript remediation
    .Version
        Pilot



#>

$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$Name = "RunAsPPL"
$Type = "DWORD" = 
$Value = 1

Try {
    $Registry = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
    If ($Registry -eq $Value){
        Write-Output "Compliant"
        Exit 0
    } 
    Write-Warning "Not Compliant"
    Exit 1
} 
Catch {
    Write-Warning "Not Compliant"
    Exit 1
}

 