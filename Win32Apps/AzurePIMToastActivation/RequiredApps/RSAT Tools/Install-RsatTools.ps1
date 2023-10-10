$RSAT = Get-WindowsCapability -online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
if ($RSAT.state -ne "Installed")
{
    Try
    {
        Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ErrorAction Stop
    }
    Catch
    {
        exit 1
    }
}
Start-Sleep -s 2
$RSAT_Verify = Get-WindowsCapability -online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
if ($RSAT_Verify.state -eq "Installed")
{
    exit 0
}
else
{
    exit 1
}
