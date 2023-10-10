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
$FolderPath = "$($env:ProgramData)\PIM_Activation" #### Change applicaiton installation path if necessary. ####
$LogFile = $FolderPath + "\$ScriptName.log"
$TranscriptFile = "$ScriptName.txt"
$TenantName = #### INSERT TENANT NAME ####
$TenantId = #### INSERT TENANT ID ####
$Target = 'https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Properties/objectId/<#### INSERT ENT APP OBJECT ID ####>/appId/<#### INSERT ENT APP APPID ####>/preferredSingleSignOnMode~/null/servicePrincipalType/Application' 
$Set_PIMRoleStatus = "$FolderPath\Set-PIMRoleStatus.ps1"
#endregion Constants

#region Functions
function logwrite
{
    Param ([string]$logstring)
    $stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $logmessage = "$stamp $logstring"
    $logmessage | out-file $logfile -Append
}

function Get-CurrentUser
{
    $Users = query user
    $Users = $Users | ForEach-Object { (($_.trim() -replace ">" -replace "(?m)^([A-Za-z0-9]{3,})\s+(\d{1,2}\s+\w+)", '$1  none  $2' -replace "\s{2,}", "," -replace "none", $null)) } | ConvertFrom-Csv
    foreach ($User in $Users)
    {
        if ($User.STATE -eq "Active")
        {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Username     = $User.USERNAME
                SessionState = $User.STATE.Replace("Disc", "Disconnected")
                SessionType  = $($User.SESSIONNAME -Replace '#', '' -Replace "[0-9]+", "")
            }
        } 
    }
}
#endregion Functions

Start-Transcript "$FolderPath\$TranscriptFile" -Append -NoClobber | Out-Null
logwrite "START: Scheduled task initiated at $ScriptTime from $ScriptPath by $($ScriptIdentity.Displayname)."

#region Modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try 
{
    $PSRepo = Get-PSRepository
    if (($PSRepo.name -eq "PSGallery") -and ($PSRepo.InstallationPolicy -eq "Untrusted"))
    {
        #### May not be needed.
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
    }
    if (!(Get-InstalledModule -Name Microsoft.Graph -RequiredVersion 1.28.0))
    {
        logwrite "INFO: Installilng Microsoft.Graph modules."
        #### Only Micrsoft.Graph version 1.28.0 is supported currently. ####
        Install-Module Microsoft.Graph -Scope AllUsers -Force -RequiredVersion 1.28.0 -ErrorAction Stop
        logwrite "INFO: Successfully installed Microsoft.Graph modules."
    }
    if (!((Get-InstalledModule -Name CredentialManager -ErrorAction SilentlyContinue) -or (Get-module -name CredentialManager)))
    {
        logwrite "INFO: Installing CredentialManager module."
        Install-Module CredentialManager -AllowClobber -Force -ErrorAction Stop
        logwrite "INFO: Successfully installed CredentialManager module."
        Import-Module CredentialManager -Force
    }
    else
    {
        Import-Module CredentialManager -Force
    }
}
catch
{
    logwrite "ERROR: Failed to install modules."
    logwrite "ERROR: $_"
    exit 1
}
#endregion Modules

#region Authentication
try
{
    $Credentails = Get-StoredCredential -Target $Target -AsCredentialObject
    $ClientId = $Credentails.UserName
    $ClientSecret = $Credentails.Password
    logwrite "INFO: Pulled credentials from Credential Manager."
}
catch
{
    logwrite "ERROR: Failed to pull credentials from credential manager."
    logwrite "ERROR: $_"
}

try
{
    $Body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $ClientId
        Client_Secret = $ClientSecret
    }
    $TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $Body
    #$TokenResponse = $TokenResponse.access_token | ConvertTo-SecureString -AsPlainText -Force #### Used in Microsoft.Graph.Authentication v2.2.0
    $TokenResponse = $TokenResponse.access_token 
    logwrite "INFO: Successfully retrieved PIM client token."
}
catch
{
    logwrite "ERROR: Failed to retrieve PIM client token."
    logwrite "ERROR: $_"
}
#endregion Authentication

#region Connect to MgGraph
try
{
    Connect-MgGraph -AccessToken $TokenResponse | Out-Null
    logwrite "INFO: Successfully connected to Microsoft Graph."
}
catch
{
    logwrite "ERROR: Failed to connect to Microsoft Graph."
    logwrite "ERROR: $_"
}
#endregion Connect to MgGraph

#region Get User Roles
try
{
    $ADUser = Get-ADUser -Identity (Get-CurrentUser | Select-Object -ExpandProperty Username) | Select-Object -ExpandProperty UserPrincipalName
    logwrite "INFO: ADUser - $ADUser"
    $CurrentUser = (Get-MgUser -Filter "UserPrincipalName eq '$ADUser'").Id
    logwrite "INFO: Cloud User - $CurrentUser"
}
catch
{
    logwrite "ERROR: Failed to get user information."
    logwrite "ERROR: $_"
}
try
{
    $CurrentlyActivatedRoles = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "principalId eq '$currentuser'"
    logwrite $($CurrentlyActivatedRoles.RoleDefinitionId)
    $MyRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentuser'"
}
catch
{
    logwrite "ERROR: Failed to get user roles."
    logwrite "ERROR: $_"
}

if ($CurrentlyActivatedRoles -and $MyRoles)
{
    $Compare = Compare-Object $($CurrentlyActivatedRoles.RoleDefinitionID) $($myroles.roledefinitionid) | Select-Object -ExpandProperty InputObject
    $RolesToActivate = @()
    Foreach ($C in $Compare)
    {
        $RolesToActivate += $MyRoles | Where-Object { $_.RoleDefinitionId -eq $C }
    }
}
else
{
    logwrite "INFO: No roles to activate."
    $RolesToActivate = $MyRoles
}
logwrite "INFO: Found $($RolesToActivate.Count) roles to activate."
foreach ($RoleToActivate in $RolesToActivate)
{
    logwrite "INFO: Avaiable roles - $($RoleToActivate.RoleDefinition.DisplayName)"
}
#endregion Get User Roles

#region Activate Roles
foreach ($role in $RolesToActivate )
{
    try
    {
        $ToastConfig = [ordered]@{
            Image     = "$FolderPath\azuread.png"
            AppId     = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
            Group     = 'PIM'
            Tag       = $($role.RoleDefinition.DisplayName)
            Arguments = "pwrshll://$($Set_PIMRoleStatus) selfActivate $($role.PrincipalId) $($role.RoleDefinitionId) $($role.DirectoryScopeId)"
        }
        logwrite "VERBOSE: $($ToastConfig.Arguments)"
        $xml = @"
            <toast duration="long" scenario="reminder" launch="group=$($ToastConfig.Group)&amp;tag=$($ToastConfig.Tag)">
                <visual>
                    <binding template="ToastGeneric">
                    <text>Azure PIM</text>
                    <text>Would you like to activate the $($ToastConfig.Tag) role?</text>
                    <image placement="appLogoOverride" src="$($ToastConfig.Image)" hint-crop="circle"/>
                    </binding>
                </visual>
                <actions>
                    <action content="Accept" arguments="$($ToastConfig.Arguments)" activationType="protocol" />
                    <action content="Dismiss" activationType="foreground" arguments="action=dismiss"/>
                    <action content="Open PIM" activationType="protocol" arguments="https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/aadmigratedroles/provider/aadroles"/>
                </actions>
                <audio src="ms-winsoundevent:Notification.Reminder"/>
            </toast>
"@
        $XmlDocument = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
        $XmlDocument.loadXml($xml)
        $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($XmlDocument)  
    }
    catch
    {
        logwrite "ERROR: Failed to pop toast notification."
        logwrite "ERROR: Failed to activate $($role.RoleDefinition.DisplayName)."
        logwrite "ERROR: $_"
    }
}
#endregion Activate Roles

Disconnect-MgGraph | Out-Null
logwrite "INFO: Disconnected from MgGraph."

if (test-path "$FolderPath\Import-PIMActivationProcess.ps1")
{
    # Import-PIMActivationProcess.ps1 script contains clientID and clientSecret. Deleting the file after the first time running this script. 
    Remove-item  -Path "$FolderPath\Import-PIMActivationProcess.ps1" -Force
    logwrite "INFO: Deleted Import-PIMActivationProcess.ps1"
}

logwrite "END: Completed $ScriptName."
Stop-Transcript
