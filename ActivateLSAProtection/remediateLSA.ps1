<#
    .Descriptions
        remediation skriptet endrer LSA status til aktivt
        
    .Author
        robwol
    
    .Version
        Pilot


#>

$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$Name = "RunAsPPL"
$Type = "DWORD"
$Value = 1

Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value 