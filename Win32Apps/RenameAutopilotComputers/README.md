# Rename Autopilot Computers

## Description
Currently, Intune/Autopilot doesn't allow you to get that creative with computer names during the Autopilot process. This application allows administratators to set the device name within the [Windows Autopilot devices](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/AutopilotDevices.ReactView/filterOnManualRemediationRequired~/false) page during initial setup and have it be enforced during the Autopilot configuration process. The idea and methodology of this process was a result of reading Michael Niehaus article at https://oofhours.com/2020/05/19/renaming-autopilot-deployed-hybrid-azure-ad-join-devices/. 

<a href="https://www.buymeacoffee.com/jwagner078g" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 45px !important;width: 163px !important;" ></a>

## Requirements
- This is for Hybrid Azure AD Joined devices only.
- Within Active Directroy Delegated Access to SELF to be able to change its own computer name.
- Intune Connector to your on-prem environment. See https://learn.microsoft.com/en-us/autopilot/windows-autopilot-hybrid
- Intune Device Categories are set and up to date. See https://learn.microsoft.com/en-us/mem/intune/enrollment/device-group-mapping

## Installation Steps
1. Create an [App Registration](https://portal.azure.com/?feature.msaljs=true#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps) within Entra ID.
   - Account Type: Single Tenant
   - Generate a clientID/clientSecret
   - Admin consent to the following permissions.
     * Application - Device.Read.All
     * Application - DeviceManagementApps.Read.All
     * Application - DeviceManagementConfiguration.Read.All
     * Application - DeviceManagementManagedDevices.PrivilegedOperations.All
     * Delegated - DeviceManagementManagedDevices.Read.All
     * Application - DeviceManagementManagedDevices.Read.All
     * Delegated - DeviceManagementManagedDevices.ReadWrite.All
     * Application - DeviceManagementManagedDevices.ReadWrite.All
     * Application - DeviceManagementServiceConfig.Read.All
2. Download the [Microsoft-Win32-Content-Prep-Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
3. Create a folder and download all the data for the project.
4. Read through each file and update the necessary information.
5. Run the Win32-Content-Prep-Tool to create a .intunewin file. See https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-prepare
6. Create an Win32 App within Intune.
   - Install Command: powershell.exe -noprofile -windowstyle Hidden -file .powershell.exe -noprofile -windowstyle Hidden -file .\Rename-AutopilotComputer.ps1\Rename-AutopilotComputer.ps1
   - Uninstall Command: cmd.exe /c del %ProgramData%\RenameComputer
   - Detection rules: Use DetectionScript-Rename-AutopilotComputer.ps1
   - Return codes:
     * 0 Success
     * 1707 Success
     * 3010 Soft reboot
     * 1641 Hard reboot
     * 1618 Retry
     * 100 Retry
     * 200 Retry
     * 300 Retry
     * 400 Retry
     * 500 Retry
     * 600 Retry
     * 700 Failed
     * 650 Retry
     * 675 Retry
     * 750 Failed
7. Deploy app as "Required".

## Deployment Flow
1. Application is deployed via Intune
2. BITS are copied to C:\ProgramData
3. Verifies device is joined to the domain and can ping the domain.
4. Retrieves a token via Invoke-RestMethod to our App Registration with the clientID and clientSecret.
5. Pulls the Windows Autopilot deviceID.
   - If the Autopilot deviceID is not set yet, we will reach out to Intune for the deviceID via the device serial number.
6. Gets the Group Tag of the Windows Autopilot device and assigns a device category equal to the Group Tag while removing the prefix of "GT - ".
7. Gets the assigned user from Windows Autopilot device and sets the primary user of the device within Intune.
8. If the device is not ready for a rename (can't ping a DC, etc), it will create a scheduled task to try again later.
9. Renames the computer within Active Directory.
10. Renames the Intune device.
11. If its successful, it will delete the scheduled task from earlier.
12. Reboots the machine.

## To-Do
- [ ] Fix issue where Intune shows status of "Rename failed".
