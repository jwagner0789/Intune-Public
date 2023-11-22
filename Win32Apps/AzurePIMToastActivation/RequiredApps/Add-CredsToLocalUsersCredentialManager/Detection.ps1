$Content = Get-content -Path "C:\ProgramData\Add-CredentialstoCredentialManager\Add-CredentialstoCredentialManager.ps1.log"
if ($Content -like "*Successully stored credentials in local credential manager.*")
{
    exit 0
}
else
{
    exit 1
}