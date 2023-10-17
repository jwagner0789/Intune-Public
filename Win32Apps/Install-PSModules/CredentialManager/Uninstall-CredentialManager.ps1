if (Get-Module -ListAvailable -Name CredentialManager)
{
    try
    {
        Uninstall-Module CredentialManager -Scope AllUsers -Force -ErrorAction Stop
        exit 0
    }
    catch
    {
        exit 1
    }    
}
