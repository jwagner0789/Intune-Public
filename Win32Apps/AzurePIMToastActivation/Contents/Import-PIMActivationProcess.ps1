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
$TrackingRegistryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Intune\Import-PIMActivationProcess"
$ScheduledTaskPath = '\<#### INSERT FOLDER NAME HERE ####>\'
$ScheduledTaskName = 'Activate-PIMRole'
$ScheduledTaskXMLFile = @(Resolve-Path ".\Activate-PIMRole.xml" | Select-Object -ExpandProperty path)
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
logwrite "START: Scheduled task initiated at $ScriptTime from $ScriptPath by $($ScriptIdentity.Displayname)."

#region Modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try 
{
    if (!(Get-PackageProvider | Where-Object { $_.Name -eq "NuGet" } -ErrorAction SilentlyContinue))
    {
        logwrite "INFO: Installing NuGet Package Provider."
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        logwrite "INFO: Installed NuGet Package Provider."
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
}
catch
{
    logwrite "ERROR: Failed to install modules."
    logwrite "ERROR: $_"
    Stop-Transcript
    exit 1
}
#endregion Modules

#region Initialize RegKeyTracking
logwrite "INFO: Creating Reg Key Path - $TrackingRegistryPath."
try
{
    New-Item -Path $TrackingRegistryPath -Force -ErrorAction Stop | Out-Null
}
catch
{
    logwrite "ERROR: $_"
}
$InitialScriptRegTrackingMap = @{
    LastRunScriptPath     = $ScriptPath
    LastRunTimeStart      = $ScriptTime
    LastRunScriptIdentity = $ScriptIdentity.DisplayName
    Status                = "Starting"
    LogFile               = "$LogFile"
}
foreach ($RegTrackingItem in $InitialScriptRegTrackingMap.GetEnumerator()) 
{
    Write-Verbose "$($RegTrackingItem.Key) - $($RegTrackingItem.Value)"
    Set-ItemProperty -Path $TrackingRegistryPath -Name $RegTrackingItem.Key -Value $RegTrackingItem.Value -Force | Out-Null
}
#endregion Initialize RegKeyTracking

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
if (test-path $FolderPath)
{
    logwrite "INFO: Copying data to $FolderPath."
    Copy-Item -Destination $FolderPath -Path ".\" -Recurse -Force -Container:$false
    logwrite "INFO: Successfully copied data to $FolderPath."
}
#endregion Copy Data to ProgramData

#region Create PowerShell Protocol Handler
try
{
    logwrite "INFO: Creating PowerShell protocol handler."
    $RegPath = "HKCR:\pwrshll\shell\open\command"
    $Command = @"
C:\ProgramData\PIM_Activation\ToastScript.cmd %1 %2
"@
    $DefaultIcon = "HKCR:\pwrshll\defaulticon\"
    if (!(Test-Path $RegPath))
    {
        New-PSDrive -PSProvider Registry -Name HKCR -Root HKEY_CLASSES_ROOT | Out-Null
        New-Item $RegPath -Force | Out-Null
        New-Item $DefaultIcon -Force | Out-Null
        New-ItemProperty -Path HKCR:\pwrshll -Name "URL Protocol" -Force | Out-Null
        Set-ItemProperty -Path $RegPath -Name '(Default)' -Value $Command -Force
        Set-ItemProperty -Path $DefaultIcon -Name '(Default)' -Value 'powershell.exe,1' -Force
        Set-ItemProperty -Path HKCR:\pwrshll -Name '(Default)' -Value 'URL:PowerShell Protocol' -Force
    }
    logwrite "INFO: Successfully created PowerShell protocol handler."
}
catch
{
    logwrite "ERROR: Failed to create PowerShell protocol handler."
    logwrite "ERROR: $_"
}
#endregion Create PowerShell Protocol Handler

#region Create Scheduled Task
try
{
    $SchTasksCommandArguments = '/Create /TN "{0}{1}" /XML "{2}"' -f @(
        $ScheduledTaskPath
        $ScheduledTaskName
        $ScheduledTaskXMLFile
    )
    Write-Verbose -Message "schtasks.exe args: $SchTasksCommandArguments"
    $SchTasksStartProcessArgs = @{
        FilePath     = 'schtasks.exe'
        ArgumentList = $SchTasksCommandArguments
        WindowStyle  = 'Hidden'
        Wait         = $true
        ErrorAction  = 'Stop'
    }
    logwrite "INFO: Creating scheduled task."
    $Process = Start-Process @SchTasksStartProcessArgs
    logwrite "INFO: Created scheduled task."
    Get-ScheduledTask -TaskName "Activate-PIMRole" | Start-ScheduledTask | Out-Null
    Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete" -Force
    logwrite "INFO: Set registry key to Complete."
    Stop-Transcript | Out-Null
    logwrite "END: $ScriptName."
    exit $Process.ExitCode
}
catch
{
    Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Failed" -Force
    Stop-Transcript | Out-Null
    exit 1
}
#endregion Create Scheduled Task

Stop-Transcript | Out-Null
