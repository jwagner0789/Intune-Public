param()

Import-Module AzureADPreview
Import-Module MgGraph

Connect-MgGraph
$DeviceCategories = Get-IntuneDeviceCategory | Select-Object -ExpandProperty displayName
Disconnect-MgGraph

Connect-AzureAD
foreach ($Department in $DeviceCategories)
{
    $Departmentname = (($Department.replace("&","and")).replace("- ","")).replace(",","")
    $Displayname = "DYN $Departmentname Devices"
    $MailNickName = $Departmentname.replace(" ","")
    $Description = "Dynamic group for all $Departmentname devices."
    # I don't like $MembershipRule... it works though
    $MembershipRule = @'
((device.deviceCategory -eq "
'@
    $MembershipRule = $MembershipRule + $Department
    $MembershipRule = $MembershipRule + @'
") and (device.accountEnabled -eq True) and (device.deviceOwnership -eq "Company") and (device.managementType -eq "MDM")) or (device.devicePhysicalIds -any _ -eq "[OrderID]:GT - 
'@
    $MembershipRule = $MembershipRule + $Department
    $MembershipRule = $MembershipRule + @'
")
'@
    New-AzureADMSGroup -Description $Description `
        -DisplayName $Displayname `
        -MailEnabled $false `
        -SecurityEnabled $true `
        -MailNickName $MailNickName `
        -GroupTypes "DynamicMembership" `
        -MembershipRule $MembershipRule `
        -MembershipRuleProcessingState "Paused" `
        -Verbose
}

Disconnect-AzureAD
