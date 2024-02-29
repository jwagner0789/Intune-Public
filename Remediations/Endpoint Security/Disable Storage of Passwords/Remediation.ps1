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
    Write-Warning "Not Compliant. Attempting remediation..."
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force
    $RemediatedRegistry = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name
    if ($RemediatedRegistry -eq $Value)
    {
        Write-Output "Fixed"
        Exit 0
    }
    else
    {
        Write-Warning "Remediation failed"
        Exit 1
    }
}