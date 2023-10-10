#region Constants
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptTime = [System.DateTime]::Now
$ScriptPath = $MyInvocation.MyCommand.Definition
$ScriptIdentity = $($CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    [PSCustomObject]@{
        Name        = $CurrentIdentity.Name
        SID         = $CurrentIdentity.User.Value
        DisplayName = "$($CurrentIdentity.Name) ($($CurrentIdentity.User.Value))"
    }
)
$FolderPath = "$($env:ProgramData)\Add-CredentialstoCredentialManager"
$LogFile = $FolderPath + "\$ScriptName.log"
#endregion Constants 

#region Functions
function logwrite
{
    Param ([string]$logstring)
    $stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $logmessage = "$stamp $logstring"
    $logmessage | out-file $logfile -Append
}
#endregion Functions

#region Copy Data to ProgramData
if (!(test-path $FolderPath))
{
    logwrite "INFO: Creating $FolderPath."
    New-Item -ItemType Directory -Path $FolderPath -Force -ErrorAction Stop
    logwrite "INFO: Successfully created $FolderPath."
}
else
{
    logwrite "INFO: $Folderpath already exists."
}
#endregion Copy Data to ProgramData

logwrite "START: Scheduled task initiated at $ScriptTime from $ScriptPath by $($ScriptIdentity.Displayname)."

if (!(Get-InstalledModule -Name CredentialManager -ErrorAction SilentlyContinue))
{
    try
    {
        logwrite "INFO: Installing CredentialManager module."
        Install-Module -Scope AllUsers CredentialManager -AllowClobber -Force -ErrorAction Stop | Out-Null
        logwrite "INFO: Installed CredentialManager module."
        Import-Module CredentialManager -Force
    }
    catch
    {
        logwrite "ERROR: Failed to install modules."
        logwrite "ERROR: $_"
        exit 1
    }
}
else
{
    Import-Module CredentialManager -Force
}
if (!((Get-InstalledModule -Name CredentialManager -ErrorAction SilentlyContinue) -or (Get-module -name CredentialManager)))
{
    logwrite "ERROR: Failed to install CredentialManager module."
    logwrite "ERROR: $_"
    exit 1
}

try
{
    logwrite "INFO: Creating local credentials."
    New-StoredCredential -Target 'https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Properties/objectId/<#### INSERT ENT APP OBJECT ID ####>/appId/<#### INSERT ENT APP APPID ####>/preferredSingleSignOnMode~/null/servicePrincipalType/Application' `
        -UserName #### client ID #### `
        -Password #### client Secret #### `
        -Persist LocalMachine | Out-Null   
    logwrite "INFO: Successully stored credentials in local credential manager."
}
catch
{
    logwrite "ERROR: Failed to create or store credentials in local credentail manager."
    logwrite "ERROR: $_"
}
logwrite "END: Completed $ScriptName."
