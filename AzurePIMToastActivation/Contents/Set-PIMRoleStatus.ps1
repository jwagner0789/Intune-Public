param (
    [parameter(Mandatory = $True, Position=0)][string]$Action,    
    [parameter(Mandatory = $True, Position=1)][string]$PrincipalId,
    [parameter(Mandatory = $True, Position=2)][string]$RoleDefinitionId,
    [parameter(Mandatory = $True, Position=3)][string]$DirectoryScopeId,
    [parameter(Mandatory = $False, Position=4)][string]$RoleDisplayname
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

#region Connect to Graph API
try
{
    Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory","RoleAssignmentSchedule.ReadWrite.Directory" | out-null
    logwrite "INFO: Successfully connected to Microsoft Graph."
}
catch
{
    logwrite "ERROR: Failed to connect to Microsoft Graph."
    logwrite "ERROR: $_"
}
#endregion Connect to Graph API

#region Activate Roles
try
{
    if ($RoleDisplayname)
    {
        logwrite "INFO: Activating RoleDisplayName: $RoleDisplayname."
    }
    else 
    {
        logwrite "INFO: Activating RoleDefinitionId:$RoleDefinitionId"
    }

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
                Duration = "PT8H"
            }
        }
    }

    Write-Verbose $($params.Action)
    Write-Verbose $($params.PrincipalId)
    Write-Verbose $($params.RoleDefinitionId)
    Write-Verbose $($params.DirectoryScopeId)
    Write-Verbose $($params.Justification)
    Write-Verbose $($params.ScheduleInfo)
    
    #$Process = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params  
    $Process = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action $($params.Action) `
                -PrincipalId $($params.PrincipalId) `
                -RoleDefinitionId $($params.RoleDefinitionId) `
                -DirectoryScopeId $($params.DirectoryScopeId) `
                -Justification $($params.Justification) `
                -ScheduleInfo $($params.ScheduleInfo) 
    if ($RoleDisplayname)
    {
        logwrite "INFO: $($Process.Status) - $RoleDisplayname."
    }
    else
    {
        logwrite "INFO: $($Process.Status) - $RoleDefinitionId."
    }
    Stop-Transcript
}
catch
{
    if ($RoleDisplayname)
    {
        logwrite "ERROR: Failed to activate RoleDisplayName: $RoleDisplayname."
    }
    else 
    {
        logwrite "ERROR: Failed to activate RoleDefinitionId:$RoleDefinitionId"
    }
    logwrite "ERROR: $_"
    Stop-Transcript
}
#endregion Activate Roles
