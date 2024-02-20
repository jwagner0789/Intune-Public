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
$FolderPath = "$($env:ProgramData)\RemoveBloatware"
$LogFile = $FolderPath + "\$ScriptName.log"
$TranscriptFile = "$ScriptName.txt"
$TrackingRegistryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Intune\Remove-Bloatware"
$WindowsInstallDate = (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime( (Get-WmiObject Win32_OperatingSystem).InstallDate )
$WindowsInstallDate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($WindowsInstallDate, [System.TimeZoneInfo]::Local.Id, 'Eastern Standard Time')
$Minus1HourDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($((Get-Date).AddHours(-1)), [System.TimeZoneInfo]::Local.Id, 'Eastern Standard Time')
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

#region Initialize RegKeyTracking
Start-Transcript "$FolderPath\$TranscriptFile" -Append -NoClobber | Out-Null
logwrite "VERBOSE: Creating Reg Key Path - $TrackingRegistryPath."
try
{
    New-Item -Path $TrackingRegistryPath -Force -ErrorAction Stop
}
catch
{
    logwrite "VERBOSE: $_"
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
    logwrite "VERBOSE: Creating Reg Keys: $($RegTrackingItem.Key) - $($RegTrackingItem.Value)"
    Set-ItemProperty -Path $TrackingRegistryPath -Name $RegTrackingItem.Key -Value $RegTrackingItem.Value -Force | Out-Null
}
#endregion Initialize RegKeyTracking

#region Initialize Logging
if (-not (Test-Path $FolderPath))
{
    try
    {
        mkdir $FolderPath
        logwrite "START: Remove Bloatware Process."
    }
    catch
    {
        $ErrorMessage = $Error[0].Exception.Message
        $ErrorResponse = $Error[0].Exception.Response
        $ErrorResponsePSObject = $ErrorResponse.PSObject.Properties
        logwrite "ERROR: Failed to create $FolderPath."
        logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
        logwrite "ERRROR Code: 100"
        exit 100
    }   
}
else
{
    logwrite "START: Remove Bloatware Process."
}
#endregion Initialize Logging

if ($WindowsInstallDate -gt $Minus1HourDateTime)
{
    logwrite "INFO: Windows installed at $WindowsInstallDate."
    logwrite "INFO: Current time minus one $Minus1HourDateTime."

    #region Apps and Programs to Remove
    $UninstallPackages = @(
        "Microsoft.Getstarted"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MixedReality.Portal"
        "Microsoft.OneConnect"
        "Microsoft.SkypeApp"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "AD2F1837.HPEasyClean"
        "AD2F1837.HPPCHardwareDiagnosticsWindows"
        "AD2F1837.HPPowerManager"
        "AD2F1837.HPPrivacySettings"
        "AD2F1837.HPProgrammableKey"
        "AD2F1837.HPQuickDrop"
        "AD2F1837.HPSupportAssistant"
        "AD2F1837.HPSystemInformation"
        "AD2F1837.HPWorkWell"
        "AD2F1837.myHP"
        "Tile.TileWindowsApplication"
        "MicrosoftTeams"
    )

    $UninstallPrograms = @(
        "HP Connection Optimizer"
        "HP Sure Recover"
        "HPSure Run Module"
        "HP Wolf Security - Console"
        "HP Client Security Manager"
        "HP Notifications"
        "HP Security Update Service"
        "HP System Default Settings"
        "HP Wolf Security"
        "HP Wolf Security Application Support for Sure Sense"
        "HP Wolf Security Application Support for Windows"
    )
    #endregion Apps and Programs to Remove

    $InstalledPackages = Get-AppxPackage -AllUsers | Where-Object { ($UninstallPackages -contains $_.Name) }
    if ($InstalledPackages.count -gt 0)
    {
        logwrite "INFO: Found $($InstalledPackages.count) appx packages to remove."
    }

    $ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { ($UninstallPackages -contains $_.DisplayName) }
    if ($ProvisionedPackages.count -gt 0)
    {
        logwrite "INFO: Found $($ProvisionedPackages.count) provisioned packages to remove."
    }
    $InstalledPrograms = Get-Package | Where-Object {($UninstallPrograms -contains $_.Name) -or ($_.name -match $UninstallPrograms) }
    if ($InstalledPrograms.count -gt 0)
    {
        logwrite "INFO: Found $($InstalledPrograms.count) installed programs to remove."
    }

    # Remove provisioned packages first
    Foreach ($ProvPackage in $ProvisionedPackages)
    {
        logwrite "INFO: Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]."
        Try
        {
            $Null = Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
            logwrite "INFO: Successfully removed provisioned package: [$($ProvPackage.DisplayName)]."
        }
        Catch
        {
            logwrite "ERROR: Failed to remove provisioned package: [$($ProvPackage.DisplayName)]."
            logwrite "ERROR: Message - $_"
        }
    }

    # Remove appx packages
    Foreach ($AppxPackage in $InstalledPackages)
    {                                        
        logwrite "INFO: Attempting to remove Appx package: [$($AppxPackage.Name)]."
        Try
        {
            $Null = Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
            logwrite "INFO: Successfully removed Appx package: [$($AppxPackage.Name)]."
        }
        Catch
        {
            logwrite "ERROR: Failed to remove Appx package: [$($AppxPackage.Name)]."
            logwrite "ERROR: Message - $_"
        }
    }

    # Remove installed programs
    Foreach ($InstalledProgram in $InstalledPrograms)
    {
        logwrite "INFO: Attempting to uninstall: [$($InstalledProgram.Name)]."
        Try
        {
            $Null = Uninstall-Package -Name $($InstalledProgram.Name) -AllVersions -Force -ErrorAction Stop
            logwrite "INFO: Successfully uninstalled: [$($InstalledProgram.Name)]."
        }
        Catch
        {
            logwrite "ERROR: Failed to uninstall: [$($InstalledProgram.Name)]."
            logwrite "ERROR: Message - $_"
        }
    }
}
else 
{
    logwrite "INFO: Windows installed at $WindowsInstallDate."
    logwrite "INFO: Current time minus one $Minus1HourDateTime."
    logwrite "INFO: Past AutoPilot deployment window."    
}

Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete" -Force
logwrite "INFO: Set registry key to Complete."
Stop-Transcript | Out-Null
logwrite "END: Remove Bloatware Process."
exit 0
