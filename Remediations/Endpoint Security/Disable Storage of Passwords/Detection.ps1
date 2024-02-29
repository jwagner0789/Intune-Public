$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$Name = "DisableDomainCreds"
$Value = "1"
$Registry = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name

If ($Registry -eq $Value)
{
    Write-Output "Compliant"
    Exit 0
} 
Else
{
    Write-Warning "Not Compliant"
    Exit 1
}