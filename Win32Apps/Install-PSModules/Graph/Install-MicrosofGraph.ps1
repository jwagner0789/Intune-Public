if (!(Get-Module -ListAvailable -Name Microsoft.Graph))
{
    try
    {
        Install-Module Microsoft.Graph -Scope AllUsers -Force -ErrorAction Stop -AllowClobber
        exit 0
    }
    catch
    {
        exit 1
    }    
}
