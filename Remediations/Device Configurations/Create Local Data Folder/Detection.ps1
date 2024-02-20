# Pull Domain/Tenant Info
$TenantGUID = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
$DnsFQNValue = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\$TenantGUID" -Name DnsFullyQualifiedName -ErrorAction SilentlyContinue
$UserEmailValue = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\$TenantGUID" -Name UserEmail -ErrorAction SilentlyContinue

# Generates folder name based on Domain/Tenant info
if ($DnsFQNValue)
{
    $DnsFQNValueTrim = $DnsFQNValue -creplace '^[^.]*.', ''
    $EntName = ($DnsFQNValueTrim).substring(0, $DnsFQNValueTrim.IndexOf('.')).ToUpper()
}
elseif ($UserEmailValue)
{
    $EntName = ($UserEmailValue -creplace '^[^@]*@', '' -replace ".mail.onmicrosoft.com", "").ToUpper()
}
$FolderPath = "$($env:ProgramData)\$EntName"

# ACL granting Users modify permissions
$SecurityDescriptor = 'O:BAG:SYD:AI(A;OICI;0x1301bf;;;BU)(A;OICIID;FA;;;SY)(A;OICIID;FA;;;BA)(A;OICIIOID;GA;;;CO)(A;OICIID;0x1200a9;;;BU)(A;CIID;DCLCRPCR;;;BU)'

# Test path and ACL
if (Test-Path $FolderPath)
{
    Write-host "$Folderpath exist."
    $EntFolderACL = Get-ACL -path $FolderPath | Select-Object -ExpandProperty Sddl
    if ($SecurityDescriptor -eq $EntFolderACL)
    {
        Write-host "ACL set correctly"
        exit 0
    }
    else
    {
        Write-Error "ACL not set correctly."
        exit 1
    }
}
else
{   
    Write-Error "$Folderpath does not exist."
    exit 1
}