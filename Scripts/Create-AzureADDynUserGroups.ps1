param(
    [string]$UserOU
)
Import-Module AzureADPreview
Import-Module ActiveDirectory

if (!($UserOU))
{
    $UserOU = "DC=" + $Env:USERDNSDOMAIN.Replace(".",",DC=")
}

Connect-AzureAD

$Departments = Get-ADUser -searchbase $UserOU -filter * -Properties department | Select-Object -ExpandProperty department | Select-Object -Unique
foreach ($Department in $Departments)
{
    $Departmentname = (($Department.replace("&","and")).replace("- ","")).replace(",","")
    $Displayname = "DYN $Departmentname Users"
    $MailNickName = $Departmentname.replace(" ","")
    $Description = "Dynamic group for all $Departmentname users."
    # I don't like $MembershipRule... it works though
    $MembershipRule = @'
(user.department -eq 
'@
    $MembershipRule = $MembershipRule + $Departmentname + ")"
    New-AzureADMSGroup -Description $Description `
        -DisplayName $Displayname `
        -MailEnabled $false `
        -SecurityEnabled $true `
        -MailNickName $MailNickName `
        -GroupTypes "DynamicMembership" `
        -MembershipRule $MembershipRule `
        -membershipRuleProcessingState "Paused" -Verbose
}
Disconnect-AzureAD
