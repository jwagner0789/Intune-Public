$Modules = Get-Module -ListAvailable -Name Microsoft.Graph -ErrorAction SilentlyContinue
if ($Modules)
{
    Write-Output "Microsoft.Graph module detected."
    exit 0
}
else 
{
    exit 1
}
