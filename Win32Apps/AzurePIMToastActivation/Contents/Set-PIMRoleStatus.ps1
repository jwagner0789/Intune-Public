param (
    [parameter(Mandatory = $True, Position = 0)][string]$Action,    
    [parameter(Mandatory = $True, Position = 1)][string]$PrincipalId,
    [parameter(Mandatory = $True, Position = 2)][string]$RoleDefinitionId,
    [parameter(Mandatory = $True, Position = 3)][string]$DirectoryScopeId,
    [parameter(Mandatory = $True, Position = 4)][string]$RoleDisplayname,
    [parameter(Mandatory = $False, Position = 5)][string]$RoleID
)

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
$FolderPath = "$($env:ProgramData)\PIM_Activation"
$LogFile = $FolderPath + "\$ScriptName.log"
$TranscriptFile = "$ScriptName.txt"
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

Start-Transcript "$FolderPath\$TranscriptFile" -Append -NoClobber | Out-Null
logwrite "START: Started $ScriptName at $ScriptTime from $ScriptPath by $($ScriptIdentity.Displayname)."

logwrite "INFO: Action: $Action"
logwrite "INFO: PrincipalId: $PrincipalId"
logwrite "INFO: RoleDefinitionId: $RoleDefinitionId"
logwrite "INFO: DirectoryScopeId: $DirectoryScopeId"
logwrite "INFO: RoleDisplayname: $RoleDisplayname"
logwrite "INFO: RoleID: $RoleID"

#region Modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try 
{
    if (!(Get-Module -ListAvailable -Name AzureADPreview))
    {
        logwrite "INFO: Installing AzureADPreview module."
        Install-Module AzureADPreview -AllowClobber -Force -ErrorAction Stop | Out-Null
        logwrite "INFO: Successfully installed AzureADPreview module."
        Import-Module AzureADPreview -Force | Out-Null
    }
    else
    {
        logwrite "INFO: Importing AzureADPreview module."
        Import-Module AzureADPreview -Force | Out-Null
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

#region Connect to Graph API
try
{
    Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory","RoleAssignmentSchedule.ReadWrite.Directory" | Out-Null
    logwrite "INFO: Successfully connected to Microsoft Graph."
}
catch
{
    logwrite "ERROR: Failed to connect to Microsoft Graph."
    logwrite "ERROR: $_"
}
#endregion Connect to Graph API

#region Connect to Azure AD
try
{
    Connect-AzureAD | Out-Null
    logwrite "INFO: Connected to AzureAD."
}
catch
{
    logwrite "ERROR: Failed to connect to AzureAD."
    logwrite "ERROR: $_"
    Stop-Transcript
    exit 2
}
#endregion Connect to Azure AD

#region Activate Roles
if ($RoleDisplayName.StartsWith("Role_-_"))
{
    try
    {
        logwrite "INFO: Activating RoleDisplayName: $RoleDisplayname."
        $ScheduleInfo = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedSchedule
        $ScheduleInfo.Type = "Once"
        $ScheduleInfo.Duration="PT9H"
        $ScheduleInfo.StartDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

        Open-AzureADMSPrivilegedRoleAssignmentRequest -ProviderId aadgroups `
            -Schedule $ScheduleInfo `
            -ResourceId $RoleID `
            -RoleDefinitionId $RoleDefinitionId `
            -SubjectId $PrincipalId `
            -Type UserAdd `
            -AssignmentState Active `
            -Reason "Scheduled Task Assignment"

        logwrite "INFO: Successfully activated $RoleDisplayname."
        Disconnect-AzureAD | Out-Null
    }
    catch
    {
        logwrite "ERROR: Failed to activate RoleDisplayName: $RoleDisplayname."
        logwrite "ERROR: $_"
    }
}
else
{
    try
    {
        logwrite "INFO: Activating RoleDisplayName: $RoleDisplayname."

        $params = @{
            action = $Action
            justification = "Scheduled Task Assignment"
            roleDefinitionId = $RoleDefinitionId
            directoryScopeId = $DirectoryScopeId
            principalId = $PrincipalId
            scheduleInfo = @{
                startDateTime = Get-Date
                expiration  = @{
                    Type = "AfterDuration"
                    Duration = "PT9H"
                }
            }
        }

        $Process = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action $($params.Action) `
            -PrincipalId $($params.PrincipalId) `
            -RoleDefinitionId $($params.RoleDefinitionId) `
            -DirectoryScopeId $($params.DirectoryScopeId) `
            -Justification $($params.Justification) `
            -ScheduleInfo $($params.ScheduleInfo) 

        logwrite "INFO: $($Process.Status) - $RoleDisplayname."
    }
    catch
    {
        logwrite "ERROR: Failed to activate RoleDisplayName: $RoleDisplayname."
        logwrite "ERROR: $_"
    }
}
Stop-Transcript
logwrite "END: Completed $ScriptName."
#endregion Activate Roles
