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

# Test path and sets ACL
if (Test-Path $FolderPath)
{
    try
    {
        $EntFolderACL = Get-ACL -path $FolderPath
        $EntFolderACL.SetSecurityDescriptorSddlForm($SecurityDescriptor)
        Set-Acl -Path $FolderPath -AclObject $EntFolderACL
        exit 0
    }
    catch
    {
        Write-Error "Failed to set ACL - $_"
        exit 1
    }
}
else
{
    try
    {
        New-Item -ItemType Directory -Path $FolderPath -Force -ErrorAction Stop
        $EntFolderACL = Get-ACL -path $FolderPath
        $EntFolderACL.SetSecurityDescriptorSddlForm($SecurityDescriptor)
        Set-Acl -Path $FolderPath -AclObject $EntFolderACL -ErrorAction stop
        exit 0
    }
    catch
    {
        Write-Error "Failed to create folder or set ACL - $_"
        exit 1
    }
}