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
$AzureADSP = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' #### Service Principal for Azure App to read role group assignments. 
$LastLogonProvider = Get-ItemPropertyValue -path "REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnProvider"
$DC = (Get-ADComputer -SearchBase "OU=Domain Controllers,DC=### Insert Domain ####") | Select-Object -ExpandProperty DNSHostName | Get-Random
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

#region Windows Hello for Business Check
$LoginProviders = @([PSCustomObject]@{Name = "PIN"; ID = '{D6886603-9D2F-4EB2-B667-1971041FA96B}'},
    [PSCustomObject]@{Name = "Fingerprint"; ID = '{BEC09223-B018-416D-A0AC-523971B639F5}'},
    [PSCustomObject]@{Name = "Face"; ID = '{8AF662BF-65A0-4D0A-A540-A338A999D36F}'},
    [PSCustomObject]@{Name = "Password"; ID = '{60B78E88-EAD8-445C-9CFD-0B87F74EA6CD}'}
)

foreach ($LoginProvider in $LoginProviders)
{ 
    if ($LoginProvider.ID -eq $LastLogonProvider)
    {
        if ($($LoginProvider.Name) -eq "Password")
        {
            logwrite "INFO: LoginProvider does not meet requirements for PIM."
            logwrite "END: Completed $ScriptName."
            Stop-Transcript
            exit
        }
        else 
        {
            logwrite "INFO: LoginProvider is Windows Hello for Business - $($LoginProvider.Name)."    
        }
    } 
} 
#endregion Windows Hello for Business Check

#region Modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try 
{
    $PSRepo = Get-PSRepository
    if (($PSRepo.name -eq "PSGallery") -and ($PSRepo.InstallationPolicy -eq "Untrusted"))
    {
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
    }
    if (!(Get-Module -ListAvailable -Name Microsoft.Graph | where-object {$_.version -eq "1.28.0"}))
    {
        logwrite "INFO: Installilng Microsoft.Graph modules."
        Install-Module Microsoft.Graph -Scope AllUsers -Force -RequiredVersion 1.28.0 -ErrorAction Stop
        logwrite "INFO: Successfully installed Microsoft.Graph modules."
    }
    if (!(Get-Module -ListAvailable -Name CredentialManager))
    {
        logwrite "INFO: Installing CredentialManager module."
        Install-Module CredentialManager -Force -ErrorAction Stop
        logwrite "INFO: Successfully installed CredentialManager module."
        Import-Module CredentialManager -Force
    }
    else
    {
        Import-Module CredentialManager -Force
    }
    if (!(Get-Module -ListAvailable -Name AzureADPreview))
    {
        logwrite "INFO: Installing AzureADPreview module."
        Install-Module AzureADPreview -Force -ErrorAction Stop
        logwrite "INFO: Successfully installed AzureADPreview module."
        Import-Module AzureADPreview -Force
    }
    else
    {
        Import-Module AzureADPreview -Force
    }
}
catch
{
    logwrite "ERROR: Failed to install modules."
    logwrite "ERROR: $_"
    Stop-Transcript
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
    $TokenResponse = $TokenResponse.access_token 
    logwrite "INFO: Successfully retrieved PIM client token."
}
catch
{
    logwrite "ERROR: Failed to retrieve PIM client token."
    logwrite "ERROR: $_"
}
#endregion Authentication

#region Connect AzureAD
try
{
    $CertThumbprint = Get-ChildItem -Path "Cert:\localmachine\my" | Where-Object {$_.Subject -eq "CN=PIMRoleGroups.sc.ohio.gov"} | Select-Object -ExpandProperty Thumbprint
    Connect-AzureAD -TenantId $TenantId -ApplicationId  $AzureADSP -CertificateThumbprint $CertThumbprint | Out-Null
    logwrite "INFO: Connected to AzureAD via certificate."
}
catch
{
    logwrite "ERROR: Failed to connect to AzureAD."
    logwrite "ERROR: $_"
}
#endregion Connect AzureAD

#region Get User Roles
try
{
    $ADUser = Get-ADUser -Identity (Get-CurrentUser | Select-Object -ExpandProperty Username) -Server $DC | Select-Object -ExpandProperty UserPrincipalName
    logwrite "INFO: ADUser - $ADUser"
    $CurrentUser = Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri "https://graph.microsoft.com/v1.0/users/$ADUser" -Method Get
    $CurrentUser_ID = $CurrentUser.Id
    logwrite "INFO: Cloud User - $CurrentUser_ID"
}
catch
{
    logwrite "ERROR: Failed to get user information."
    logwrite "ERROR: $_"
}
try
{
    #region Get Active Assignments
    $URI_MgRoleManagementDirectoryRoleAssignmentScheduleInstance = @'
https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?$filter=principalId eq '
'@
    $URI_MgRoleManagementDirectoryRoleAssignmentScheduleInstance = $URI_MgRoleManagementDirectoryRoleAssignmentScheduleInstance + $CurrentUser_ID + "'"
    $ActiveAssignments = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Method Get).Value
    #endregion Get Active Assignments

    #region Get Eligible Assignments
    $URI_MgRoleManagementDirectoryRoleEligibilitySchedule = @'
https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilitySchedules?$filter=principalId eq '
'@
    $URI_MgRoleManagementDirectoryRoleEligibilitySchedule = $URI_MgRoleManagementDirectoryRoleEligibilitySchedule + $CurrentUser_ID + "'"
    $EligibleAssignments = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_MgRoleManagementDirectoryRoleEligibilitySchedule -Method Get).Value
    #endregion Get Eligible Assignments

    #region Get Role Groups 
    $URI_PIMRoleGroups = @'
https://graph.microsoft.com/v1.0/groups?$filter=isAssignableToRole eq true and mailEnabled eq false and startsWith(displayName ,'Role - ')
'@
    $PIMRoleGroups = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_PIMRoleGroups -Method Get).Value
    $URI_UserMemberof = "https://graph.microsoft.com/v1.0/users/$CurrentUser_ID/memberof"
    $UserMemberOf = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_UserMemberof -Method Get).Value
    
    $PIMRoleGroups_UserData = foreach ($PIMRoleGroup in $PIMRoleGroups)
    {
        $URI_ActiveAssignments_PIMGroups = @'
https://graph.microsoft.com/beta/identityGovernance/privilegedAccess/group/assignmentSchedules?filter=accessId eq 'member' and groupId eq '
'@
        $URI_ActiveAssignments_PIMGroups = $URI_ActiveAssignments_PIMGroups + $($PIMRoleGroup.ID) + "'"
        $ActiveAssignments_PIMGroups = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_ActiveAssignments_PIMGroups -Method get).Value
        
        $URI_EligibleAssignments_PIMGroups = @'
https://graph.microsoft.com/beta/identityGovernance/privilegedAccess/group/eligibilitySchedules?filter=accessId eq 'member' and groupId eq '
'@
        $URI_EligibleAssignments_PIMGroups = $URI_EligibleAssignments_PIMGroups + $($PIMRoleGroup.ID) + "'"
        $EligibleAssignments_PIMGroups = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_EligibleAssignments_PIMGroups -Method get).Value
        if ($EligibleAssignments_PIMGroups)
        {
            $Compare_EligibleGroup_UserMemberOf = Compare-Object $UserMemberOf.ID $EligibleAssignments_PIMGroups.principalId -IncludeEqual -ErrorAction SilentlyContinue | Where-Object { $_.SideIndicator -eq '==' }
            if ($Compare_EligibleGroup_UserMemberOf)
            {
                [PSCustomObject]@{
                    ActivelyAssignedUsersID = $ActiveAssignments_PIMGroups.principalId
                    CreatedDateTime         = $EligibleAssignments_PIMGroups.createdDateTime
                    CreatedUsing            = $EligibleAssignments_PIMGroups.createdUsing
                    DisplayName             = $PIMRoleGroup.displayName
                    EligibleGroupID         = $EligibleAssignments_PIMGroups.principalId
                    IsMemberofEligibleGroup = if ($Compare_EligibleGroup_UserMemberOf) { $true } else { $false }
                    IsCurrentlyActive       = if ($ActiveAssignments_PIMGroups.principalId -contains $CurrentUser_ID) { $true } else { $false }
                    MemberType              = $EligibleAssignments_PIMGroups.memberType
                    ResourceID              = $PIMRoleGroup.ID
                    RoleDefinitionID        = Get-AzureADMSPrivilegedRoleDefinition -ProviderId aadgroups -ResourceId $PIMRoleGroup.ID -Filter "DisplayName eq 'Member'" | Select-Object -ExpandProperty ID
                    Status                  = $EligibleAssignments_PIMGroups.status
                    ScheduleInfo            = $EligibleAssignments_PIMGroups.scheduleInfo
                }
            }
        }
    }
    #endregion Get Role Groups
}
catch
{
    logwrite "ERROR: Failed to get user roles."
    logwrite "ERROR: $_"
}
#endregion Get User Roles

#region Create list of roles to activate
$RolesToActivate = @()
if ($ActiveAssignments -and $EligibleAssignments)
{
    $Compare = Compare-Object $($ActiveAssignments.RoleDefinitionID) $($EligibleAssignments.roledefinitionid) | Select-Object -ExpandProperty InputObject
    Foreach ($C in $Compare)
    {
        if ($EligibleAssignments.RoleDefinitionId -eq $C)
        {
            $RoleID = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty RoleDefinitionId
            $URI_GetDirectoryRoles = @'
https://graph.microsoft.com/v1.0/directoryRoles?$filter=roleTemplateId eq '
'@
            $URI_GetDirectoryRoles = $URI_GetDirectoryRoles + $RoleID + "'"
            $DirectoryRole = (Invoke-RestMethod -Headers @{Authorization = "Bearer $TokenResponse" } -Uri $URI_GetDirectoryRoles -Method get).Value
            $RolesToActivate += [PSCustomObject]@{
                CreatedDateTime  = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty CreatedDateTime
                CreatedUsing     = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty CreatedUsing
                DirectoryScopeId = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty DirectoryScopeId
                DisplayName      = $DirectoryRole.DisplayName
                Id               = ''
                MemberType       = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty MemberType
                ModifiedDateTime = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty ModifiedDateTime
                PrincipalId      = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty PrincipalId
                RoleDefinitionId = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty RoleDefinitionId
                ScheduleInfo     = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty ScheduleInfo
                Status           = $EligibleAssignments | where-object { $_.RoleDefinitionId -eq $C } | Select-Object -ExpandProperty Status
            }
        }
    }
}
if ($PIMRoleGroups_UserData)
{
    foreach ($PIMRoleGroup_UserData in $PIMRoleGroups_UserData)
    {
        $RolesToActivate += [PSCustomObject]@{
            CreatedDateTime  = $PIMRoleGroup_UserData.StartDateTime
            CreatedUsing     = $PIMRoleGroup_UserData.CreatedUsing
            DirectoryScopeId = '/'
            DisplayName      = $PIMRoleGroup_UserData.DisplayName
            Id               = $PIMRoleGroup_UserData.ResourceID
            MemberType       = $PIMRoleGroup_UserData.MemberType
            ModifiedDateTime = (Get-Date)
            PrincipalId      = $CurrentUser_ID
            RoleDefinitionId = $PIMRoleGroup_UserData.RoleDefinitionID
            ScheduleInfo     = $PIMRoleGroup_UserData.ScheduleInfo
            Status           = $PIMRoleGroup_UserData.Status
        }
    }
} 
#endregion Create list of roles to activate

Disconnect-AzureAD | Out-Null

if ($RolesToActivate.count -le 0)
{
    logwrite "INFO: No roles to activate."
}
else
{
    logwrite "INFO: Found $($RolesToActivate.Count) roles to activate."
    foreach ($RoleToActivate in $RolesToActivate)
    {
        logwrite "INFO: Avaiable roles - $($RoleToActivate.DisplayName)"
    }
}

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
            Arguments = "pwrshll://$($Set_PIMRoleStatus) selfActivate $($Role.PrincipalId) $($Role.RoleDefinitionId) $($Role.DirectoryScopeId) $(($Role.DisplayName).Replace(' ','_')) $($Role.ID)"
        }
        logwrite "VERBOSE: $($ToastConfig.Arguments)"
        $xml = @"
            <toast duration="long" scenario="reminder" launch="group=$($ToastConfig.Group)&amp;tag=$($ToastConfig.Tag)">
                <visual>
                    <binding template="ToastGeneric">
                    <text>Azure PIM</text>
                    <text>Would you like to activate the $($Role.DisplayName) role?</text>
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

if (test-path "$FolderPath\Import-PIMActivationProcess.ps1")
{
    # Import-PIMActivationProcess.ps1 script contains clientID and clientSecret. Deleting the file after the first time running this script. 
    Remove-item  -Path "$FolderPath\Import-PIMActivationProcess.ps1" -Force
    logwrite "INFO: Deleted Import-PIMActivationProcess.ps1"
}

logwrite "END: Completed $ScriptName."
Stop-Transcript
