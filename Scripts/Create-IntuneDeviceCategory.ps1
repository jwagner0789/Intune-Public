param(
    [string]$UserOU
)
Import-Module MgGraph
Import-Module ActiveDirectory

if (!($UserOU))
{
    $UserOU = "DC=" + $Env:USERDNSDOMAIN.Replace(".",",DC=")
}

Connect-MgGraph

$Departments = Get-ADUser -searchbase $UserOU -filter * -Properties department | Select-Object -ExpandProperty department | Select-Object -Unique
foreach ($Department in $Departments)
{
    $Description = "AD Department: $Department"
    New-IntuneDeviceCategory -displayName $Department -description $Description -Verbose
}

Disconnect-MgGraph
