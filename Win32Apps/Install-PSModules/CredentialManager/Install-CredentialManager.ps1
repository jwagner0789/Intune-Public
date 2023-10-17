if (!(Get-Module -ListAvailable -Name CredentialManager))
{
    try
    {
        Install-Module CredentialManager -Scope AllUsers -Force -ErrorAction Stop -AllowClobber
        exit 0
    }
    catch
    {
        exit 1
    }    
}
