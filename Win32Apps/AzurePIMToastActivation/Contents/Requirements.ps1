if (Get-ChildItem -Path Cert:\LocalMachine\My -DnsName ### Insert Cert Name ### | Where-Object { $_.Thumbprint -eq "### Insert Cert Thumbprint ###" })
{
    Write-Output "Certificate detected."
    exit 0
}
else
{
    Write-Output "Certificate not installed!"
    exit 1
}
