if (Get-Module -ListAvailable -Name CredentialManager -ErrorAction SilentlyContinue)
{
    Write-Output "CredentialManager module detected."
    exit 0
}
else 
{
    exit 1
}
