Param()

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
$SerialNumber = Get-WmiObject win32_bios | Select-Object -ExpandProperty serialnumber
$CurrentComputerName = $env:ComputerName
$FolderPath = "$($env:ProgramData)\RenameComputer"
$LogFile = $FolderPath + "\$ScriptName.log"
$TranscriptFile = "$ScriptName.txt"
$TrackingRegistryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Autopilot\ComputerRename"
$Continue = $true
$TaskName = "Autopilot - RenameComputer"
#endregion Constants

#region Functions
function logwrite
{
    Param ([string]$logstring)
    $stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $logmessage = "$stamp $logstring"
    $logmessage | out-file $logfile -Append
}

function logErrorMessage
{
    Param (
        [string]$ErrorMessage,
        [string]$ErrorResponse,
        [string]$ErrorResponsePSObject
    )
    logwrite "ERROR: Message - $ErrorMessage"
    logwrite "ERROR: Start details"
    foreach ($ErrorResponseObject in $ErrorResponsePSObject)
    {
        logwrite "Object name: $($ErrorResponseObject.name)"
        logwrite "Object value: $($ErrorResponseObject.value)"
    }
    logwrite "ERROR: End Details"
}
#endregion Functions

#region Initialize RegKeyTracking
Start-Transcript "$FolderPath\$TranscriptFile" -Append -NoClobber | Out-Null
if (!(Test-Path $TrackingRegistryPath))
{
    logwrite "VERBOSE: Creating Reg Key Path."
    New-Item -Path $TrackingRegistryPath -Force | Out-Null
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
    Set-ItemProperty -Path $TrackingRegistryPath -Name $RegTrackingItem.Key -Value $RegTrackingItem.Value | Out-Null
}
#endregion Initialize RegKeyTracking

#region Initialize Logging
if (-not (Test-Path $FolderPath))
{
    try
    {
        mkdir $FolderPath
        logwrite "Starting - Computer Rename Process."
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
    logwrite "Starting Computer Rename Process"
}
logwrite "INFO: Computer serial number is $SerialNumber."
#endregion Initialize Logging

#region Check Domain Joined
$domainjoined = Get-ComputerInfo -Property cspartofdomain | Select-Object CsPartOfDomain
if (-not $domainjoined)
{
    logwrite "WARNING: Computer is not domain joined."
    $Continue = $false
}
else
{
    logwrite "INFO: Computer is domain joined."    
}
#endregion Check Domain Joined

#region Ping Domain
if (-not (Test-Connection -Count 1 -Quiet -ComputerName $env:USERDNSDOMAIN))
{
    logwrite "WARNING: Computer can't ping a DC."
    $Continue = $false
}
else
{
    logwrite "INFO: Successfully pinged $($env:USERDNSDOMAIN)."
}
#endregion Ping Domain

if ($Continue)
{
    #region Authenticate
    $ClientId = <### INSERT APP REG clientID ###>
    $ClientSecret = <### INSERT APP Reg clientSecret ###>
    $TenantName = <### INSERT Tenant Name ###>
    $Body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $ClientId
        Client_Secret = $ClientSecret
    }
    try
    {
        $TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $Body
        logwrite "INFO: Successfully authenticated to MS Graph."    
    }
    catch
    {
        $ErrorMessage = $Error[0].Exception.Message
        $ErrorResponse = $Error[0].Exception.Response
        $ErrorResponsePSObject = $ErrorResponse.PSObject.Properties
        logwrite "ERROR: Failed to pull token from MS Graph."
        logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
        logwrite "ERROR Code: 200"
        exit 200 
    }
    #endregion Authenticate 

    #region Pull Autopilot information
    try
    {
        $AutopilotDeviceUri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities"  
        $AutopilotDevices = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)" } -Uri $AutopilotDeviceUri -Method Get).value 
        $FindDevice = $AutopilotDevices | where-object { $_.SerialNumber -eq $SerialNumber }
        $AutopilotDisplayName = $FindDevice | Select-Object -ExpandProperty displayName
        $AutopilotGroupTag = $FindDevice | Select-Object -ExpandProperty groupTag
        $AutopilotAssignedUser = $FindDevice | Select-Object -ExpandProperty userPrincipalName
        $ManagedDeviceID = $FindDevice | Select-Object -ExpandProperty managedDeviceId
        logwrite "INFO: Found device."
        logwrite "INFO: Autopilot device name is $AutopilotDisplayName."
        logwrite "INFO: Autopilot device ID is $ManagedDeviceID."
        logwrite "INFO: Autopilot device group tag is $AutopilotGroupTag."
        logwrite "INFO: Autopilot assigned user is $AutopilotAssignedUser."
    }
    catch
    {
        $ErrorMessage = $Error[0].Exception.Message
        $ErrorResponse = $Error[0].Exception.Response
        $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
        logwrite "ERROR: Failed to pull Autopilot details."
        logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
        logwrite "ERROR Code: 300"
        exit 300
    }
    #endregion Pull Autopilot information

    #region Pull Intune Information
    if ($ManagedDeviceID -eq '00000000-0000-0000-0000-000000000000')
    {
        try
        {
            $GetIntuneDeviceUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=serialNumber eq '$SerialNumber'"
            $GetIntuneDevice = Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)" } -Uri $GetIntuneDeviceUri -Method Get
            $IntuneDeviceName = (($GetIntuneDevice | Select-Object Value).Value).deviceName
            $DeviceCategory = $GetIntuneDevice.deviceCategoryDisplayName
            $ManagedDeviceID = (($GetIntuneDevice | Select-Object Value).Value).id
            logwrite "INFO: Intune had a null device ID. Querying serial number..."
            logwrite "INFO: Found Intune device."
            logwrite "INFO: Intune device name is $IntuneDeviceName."
            logwrite "INFO: Intune device ID is $ManagedDeviceID."
            logwrite "INFO: Intune device category is $DeviceCategory"
        }
        catch
        {
            $ErrorMessage = $Error[0].Exception.Message
            $ErrorResponse = $Error[0].Exception.Response
            $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
            logwrite "ERROR: Failed to pull Intune details without ManagedID."
            logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
            logwrite "ERROR Code: 400"
            exit 400
        }
    }
    else
    {
        try
        {
            $GetIntuneDeviceUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$ManagedDeviceID"
            $GetIntuneDevice = Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)" } -Uri $GetIntuneDeviceUri -Method Get
            $IntuneDeviceName = $GetIntuneDevice.deviceName
            $DeviceCategory = $GetIntuneDevice.deviceCategoryDisplayName
            logwrite "INFO: Found Intune device."
            logwrite "INFO: Intune device name is $IntuneDeviceName."
            logwrite "INFO: Intune device ID is $ManagedDeviceID."
            logwrite "INFO: Intune device category is $DeviceCategory."
        }
        catch
        {
            $ErrorMessage = $Error[0].Exception.Message
            $ErrorResponse = $Error[0].Exception.Response
            $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
            logwrite "ERROR: Failed to pull Intune details."
            logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
            logwrite "ERROR Code: 500"
            exit 500
        }
    }
    #endregion Pull Intune Information

    #region Set Intune Device Category
    if ((!$DeviceCategory) -and $AutopilotGroupTag)
    {
        $NewDeviceCategory = ($AutopilotGroupTag.replace("GT - ", "")).replace("&", "%26")
        #$IntuneDeviceCategoryUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCategories?$filter=contains(displayName,'$NewDeviceCategory') "
        $IntuneDeviceCategoryUri = @'
https://graph.microsoft.com/v1.0/deviceManagement/deviceCategories?$filter=contains(displayName,'
'@
        $IntuneDeviceCategoryUri = $IntuneDeviceCategoryUri + $NewDeviceCategory
        $IntuneDeviceCategoryUri = $IntuneDeviceCategoryUri + @'
')
'@
        $IntuneDeviceCategory = Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)" } -Uri $IntuneDeviceCategoryUri -Method GET
        $IntuneDeviceCategoryID = ($IntuneDeviceCategory | Select-Object value).value | Select-Object -ExpandProperty ID    
        $SetDeviceCategoryUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$ManagedDeviceID/deviceCategory/`$ref"
        $SetDeviceCategoryBody = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$IntuneDeviceCategoryID" } | ConvertTo-Json
        try
        {
            $SetDeviceCategory = Invoke-RestMethod -Headers @{Authorization = "Bearer $($TokenResponse.access_token)" } -Uri $SetDeviceCategoryUri -Method PUT -Body $SetDeviceCategoryBody -ContentType 'application/json' -ErrorAction Stop
            logwrite "INFO: Successfully changed device category."
            if ($SetDeviceCategory)
            {
                logwrite "INFO: Set device category output: $SetDeviceCategory"
            }
        }
        catch
        {
            $ErrorMessage = $Error[0].Exception.Message
            $ErrorResponse = $Error[0].Exception.Response
            $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
            logwrite "ERROR: Failed to set Intune device category."
            logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
            logwrite "ERROR Code: 550"
            exit 550
        }
    }
    elseif ($DeviceCategory -and (!$AutopilotGroupTag))
    {
        logwrite "INFO: Intune device category is $DeviceCategory." 
        logwrite "WARNING: Autopilot group tag has not been set."
    }
    elseif ( (!$DeviceCategory) -and (!$AutopilotGroupTag))
    {
        logwrite "WARNING: Autopilot group tag has not been set."
        logwrite "WARNING: Intue device category will need to be manually set as Autopilot group tag is not set."
    }
    #endregion Set Intune Device Category

    #region Pull or Set Primary User
    try
    {
        $GetDevicePrimaryUserUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$ManagedDeviceID/users"
        $GetDevicePrimaryUser = Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)" } -Uri $GetDevicePrimaryUserUri -Method Get
        $PrimaryUser = ($GetDevicePrimaryUser | Select-Object Value).Value
    }
    catch
    {
        $ErrorMessage = $Error[0].Exception.Message
        $ErrorResponse = $Error[0].Exception.Response
        $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
        logwrite "ERROR: Failed to pull primary users."
        logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
        logwrite "ERROR Code: 600"
        exit 600
    }
    if ($PrimaryUser)
    {
        $PrimaryUserDisplayName = $PrimaryUser.displayName
        $PrimaryUserID = $PrimaryUser.id
        $PrimaryUserLastName = $PrimaryUser.surname
        logwrite "INFO: Primary user is $PrimaryUserDisplayName."
        logwrite "INFO: Primary user ID is $PrimaryUserID."
        logwrite "INFO: Primary user last name is $PrimaryUserLastName."
    }
    elseif ((!$PrimaryUser) -and $AutopilotAssignedUser)
    {
        try
        {
            $GetAzureADUserUri = "https://graph.microsoft.com/v1.0/users/$AutopilotAssignedUser"
            $GetAzureADUser = Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)" } -Uri $GetAzureADUserUri -Method Get
            $GetAzureADUserID = $GetAzureADUser | Select-Object -ExpandProperty id
            $PrimaryUserLastName = $GetAzureADUser | Select-Object -ExpandProperty surname
            $AzureADUserIDBody = @{"@odata.id" = "https://graph.microsoft.com/v1.0/users/$GetAzureADUserID" } | ConvertTo-Json
            logwrite "INFO: Primary User AzureAD ID is $GetAzureADUserID."
        }
        catch
        {
            $ErrorMessage = $Error[0].Exception.Message
            $ErrorResponse = $Error[0].Exception.Response
            $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
            logwrite "ERROR: Failed to pull primary user ID."
            logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
            logwrite "ERROR Code: 650"
            exit 650
        }
        try
        {
            $SetIntuneDevicePrimaryUserUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$ManagedDeviceID/users/`$ref"
            $SetIntuneDevicePrimaryUser = Invoke-RestMethod -Uri $SetIntuneDevicePrimaryUserUri -Headers @{Authorization = "Bearer $($TokenResponse.access_token)" } -Method POST -Body $AzureADUserIDBody -ContentType 'application/json'
            logwrite "INFO: Successfuly set Intune Primary User."
        }
        catch
        {
            $ErrorMessage = $Error[0].Exception.Message
            $ErrorResponse = $Error[0].Exception.Response
            $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
            logwrite "ERROR: Failed to set Intune primary user."
            logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
            logwrite "ERROR Code: 675"
            exit 675
        }
    }
    #endregion Pull or Set Primary User
    
    #region Rename Computer
    if (($CurrentComputerName -eq $IntuneDeviceName) -and ($CurrentComputerName -eq $AutopilotDisplayName) -and ($IntuneDeviceName -eq $AutopilotDisplayName))
    {
        logwrite "INFO: Computer name matches Autopilot Device name and Intune Device name."
        Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
    }
    elseif ($CurrentComputerName -eq $AutopilotDisplayName)
    {
        logwrite "INFO: Current name matches Autopilot. Intune needs to sync."
        Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
    }
    else
    {
        if ($AutopilotDisplayName)
        {
            #region On-Prem Rename
            logwrite "INFO: Renaming AD computer from $CurrentComputerName to $AutopilotDisplayName."
            try
            {
                Rename-Computer -NewName $AutopilotDisplayName -Force -ErrorAction Stop | Out-Null
                logwrite "INFO: Successfully renamed computer to $AutopilotDisplayName."
            }
            catch
            {
                $ErrorMessage = $Error[0].Exception.Message
                $ErrorResponse = $Error[0].Exception.Response
                $ErrorResponsePSObject = $ErrorResponse.PSObject.Properties
                logwrite "ERROR: Failed to rename computer."
                logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
                logwrite "ERROR Code: 700"
                exit 700
            }
            #endregion On-Prem Rename

            #region Intune Rename
            logwrite "INFO: Renaming Intune device from $CurrentComputerName to $AutopilotDisplayName."
            try
            {
                $RenameIntuneDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$ManagedDeviceID/setDeviceName"
                $RenameBody = @'
{
"deviceName":"
'@
                $RenameBody = $RenameBody + $AutopilotDisplayName + '"' +
                @'

}
'@
                $RenameIntuneDevice = Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)" } -Uri $RenameIntuneDeviceUri -Method POST -Body $RenameBody -ContentType 'application/json' -ErrorAction Stop
                $RenameResult = ($RenameIntuneDevice | Select-Object Value).Value
                logwrite "INFO: Successfully renamed device in Intune."
                if ($RenameIntuneDevice)
                {
                    logwrite "INFO: Intune rename result: $RenameIntuneDevice."
                    logwrite "INFO: Intune rename result value: $($RenameIntuneDevice.value)"
                }
                if ($RenameResult)
                {
                    logwrite "INFO: Intune rename result selected value $RenameResult."
                }
            }
            catch
            {
                $ErrorMessage = $Error[0].Exception.Message
                $ErrorResponse = $Error[0].Exception.Response
                $ErrorResponsePSObject = $ErrorResponse.ResponseUri.OriginalString
                logwrite "ERROR: Failed to rename computer in Intune."
                logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject
                logwrite "ERROR Code: 750"
                exit 750
            }
            #endregion Intune Rename

            #region ScheduledTask
            $ScheduledTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($ScheduledTask)
            {
                try
                {
                    Disable-ScheduledTask -TaskName $TaskName -ErrorAction Stop
                    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
                    logwrite "INFO: Removed Scheduled Task."
                    Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
                }
                catch
                {
                    $ErrorMessage = $Error[0].Exception.Message
                    $ErrorResponse = $Error[0].Exception.Response
                    $ErrorResponsePSObject = $ErrorResponse.PSObject.Properties
                    logwrite "ERROR: Failed to remove scheduled task."
                    logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject 
                }   
            }
            #endregion ScheduledTask

            #region Reboot
            if ((Get-ComputerInfo -Property csusername) -match "defaultUser")
            {
                logwrite "INFO: Exiting during ESP/OOBE with return code 1641."
                Stop-Transcript | Out-Null 
                Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
                try
                {
                    Remove-Item -Path "$FolderPath\$ScriptName" -Force | Out-Null
                }
                catch
                {
                    logwrite "WARNING: Failed to remove $ScriptName."
                }
                exit 1641
            }
            else
            {
                logwrite "INFO: Restarting computer in 10 minutes."
                & shutdown.exe /g /t 300 /f /c "Restarting the computer due to a computer name change.  Save your work."
                Stop-Transcript | Out-Null
                Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
                try
                {
                    Remove-Item -Path "$FolderPath\$ScriptName" -Force | Out-Null
                }
                catch
                {
                    logwrite "WARNING: Failed to remove $ScriptName."
                }
                    exit 0
                }
            #endregion Reboot
            
        }   
        else
        {
            logwrite "WARNING: Autopilot display name has not been updated."
            logwrite "INFO: Creating a scheduled task to run later."
            $ScheduledTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if ($ScheduledTask)
            {
                logwrite "INFO: Scheduled task already exists."
                Stop-Transcript | Out-Null
                Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
                exit 0
            }
            else
            {
                if (-not (Test-Path "$FolderPath\$ScriptName"))
                {
                    try
                    {
                        Copy-item $PSCommandPath "$FolderPath\$ScriptName" | Out-Null
                        logwrite "INFO: Copied $ScriptName to $FolderPath."
                    }
                    catch
                    {
                        $ErrorMessage = $Error[0].Exception.Message
                        $ErrorResponse = $Error[0].Exception.Response
                        $ErrorResponsePSObject = $ErrorResponse.PSObject.Properties
                        logwrite "ERROR: Failed to copy script to computer."
                        logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject 
                    }
                }
                if (Test-Path "$FolderPath\$ScriptName")
                {
                    try
                    {
                        $Action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoProfile -ExecutionPolicy bypass -WindowStyle Hidden -File $($FolderPath)\$($ScriptName)"
                        $TimeSpan = New-Timespan -minutes 5
                        $Triggers = @()
                        $Triggers += New-ScheduledTaskTrigger -Daily -At 9am
                        $Triggers += New-ScheduledTaskTrigger -AtLogOn -RandomDelay $TimeSpan
                        $Triggers += New-ScheduledTaskTrigger -AtStartup -RandomDelay $TimeSpan
                        Register-ScheduledTask -User SYSTEM -Action $Action -Trigger $Triggers -TaskName $TaskName -Description "Renaming computer during Autopilot process." -Force | out-null
                        Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
                        logwrite "INFO: Successfully created Scheduled task."
                    }
                    catch
                    {
                        $ErrorMessage = $Error[0].Exception.Message
                        $ErrorResponse = $Error[0].Exception.Response
                        $ErrorResponsePSObject = $ErrorResponse.PSObject.Properties
                        logwrite "ERROR: Failed to create Scheduled Task."
                        logErrorMessage -ErrorMessage $ErrorMessage -ErrorResponse $ErrorResponse -ErrorResponsePSObject $ErrorResponsePSObject 
                    }
                }
                Set-ItemProperty -Path $TrackingRegistryPath -Name "Status" -Value "Complete"
                logwrite "INFO: Set registry key to Complete."
                Stop-Transcript | Out-Null
            }
        }
    }
    #endregion Rename Computer
    logwrite "INFO: Ending Computer Rename Process"
    Stop-Transcript
    exit 0
}