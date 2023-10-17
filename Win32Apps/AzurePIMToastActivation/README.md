# Azure PIM Activation Toast

![alt text](https://github.com/jwagner0789/IntuneMgmt/blob/main/Win32Apps/AzurePIMActivationToast/AzurePIMToast-GlobalAdmin.png?raw=true)

## Description
Privileged Identity Management is a Microsoft Entra ID service that allows for just-in-time (JIT) role based access control (RBAC) assignments. This is a great security feature, however, if the roles that are assigned to your account must be used everyday, going to the Azure portal and activating them day in and day out is very tedious. This application will prompt via a toast notification of all roles avaiable to you, for activation at login.

<a href="https://www.buymeacoffee.com/jwagner078g" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 45px !important;width: 163px !important;" ></a>

## Security Concerns
Its highly recommened to have Conditional Access policies setup to ensure users must MFA for each role activation. This can be accomplished multiple different ways and to follow your companies security policies.

## Requirements 
- RSAT Tools must be installed on client computer. You can use the Win32App deployment found in [./RequiredApps](https://github.com/jwagner0789/IntuneMgmt/tree/main/Win32Apps/AzurePIMActivationToast/RequiredApps/RSAT%20Tools).
- Credentails for your App Registration must be deployed to the users credential manager. You can use the Win32App deployment found in [./RequiredApps](https://github.com/jwagner0789/IntuneMgmt/tree/main/Win32Apps/AzurePIMActivationToast/RequiredApps/Add-CredsToLocalUsersCredentialManager).
- Helps to have the below PowerShell modules installed prior to installation. Speeds up the process.
  * [Microsoft.Graph v 1.28](https://www.powershellgallery.com/packages/Microsoft.Graph/1.28.0) (2.X.X is not supported currently).
  * [CredentialManager](https://www.powershellgallery.com/packages/CredentialManager/2.0)
- For PIM Role Groups, a certificate is needed along with another App Registration. 

## Installation Steps
1. Create an [App Registration](https://portal.azure.com/?feature.msaljs=true#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps) within Entra ID used for PIM Role activation.
   - Account Type: Single Tenant
   - Generate a clientID/clientSecret
   - Admin consent to the following Applicaiton permissions.
     * PrivilegedAccess.Read.AzureAD
     * RoleAssignmentSchedule.Read.Directory
     * RoleAssignmentSchedule.ReadWrite.Directory
     * RoleManagement.ReadWrite.Directory
     * User.Read.All - likely can do without this one.
2. Create a second [App Registration](https://portal.azure.com/?feature.msaljs=true#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps) within Entra ID used for PIM Role Group activation.
   - Account Type: Single Tenant
   - Generate a [self signed certificate](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-self-signed-certificate).
   - Admin consent to the following Applicaiton permissions.
     * PrivilegedAccess.Read.AzureADGroup
3. Download the [Microsoft-Win32-Content-Prep-Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
4. Create a folder and download all the data within the [Contents](https://github.com/jwagner0789/IntuneMgmt/tree/main/Win32Apps/AzurePIMActivationToast/Contents) for the project.
5. Read through each file and update the necessary information.
6. Run the Win32-Content-Prep-Tool to create a .intunewin file. See https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-prepare
7. Create an Win32 App within Intune.
   - Install Command: powershell.exe -noprofile -windowstyle Hidden -executionpolicy bypass -file .\Import-PIMActivationProcess.ps1
   - Uninstall Command: cmd.exe /c del %ProgramData%\PIM_Activation
   - Requirement Script: [Requirements.ps1](https://github.com/jwagner0789/Intune-Public/blob/main/Win32Apps/AzurePIMToastActivation/Contents/Requirements.ps1)
   - Detection rules:
     * Key Path: HKEY_LOCAL_MACHINE\SOFTWARE\Intune\Import-PIMActivationProcess
     * Value name: Status
     * Detection method: String comparison
     * Operator: Equals
     * Value: Complete
   - Dependencies:
     * If you use Win32Apps to deploy RSAT tools and/or the credentials from step 1, set them as dependent applications that will automatically install.
8. Deploy app.

## Deployment Flow
1. Application is deployed via Intune
2. BITS are copied to C:\ProgramData
3. A Protocol Handler is created.
   - Great article by Gannon Novak at https://smbtothecloud.com/deploy-custom-toast-notifications-with-intune-how-to-run-scripts-from-the-action-buttons-part-1/
4. Import the Scheduled Task.
5. Scheduled task is triggered 30 seconds after login.
6. The Scheduled tasks action is to run a VB script that calls Activate-PIM.ps1. Purpose of this is to prevent a window from appearing when calling Activate-PIM.ps1.
7. Activate-PIM.ps1 will first retrieve a token from the local credential manager via Invoke-RestMethod to our App Registration with the clientID and clientSecret.
8. Connects to Microsoft Graph.
9. Pulls all the current unactivated roles that are assigned to the logged in user.
10. Connects to AzureAD.
11. Pulls all current unactivated role groups that are available to the logged in user.
12. Pops a toast notification.

## To-Do
- [x] Fix installing of Credential Manager module.
- [x] Support Azure PIM Role Groups.
- [ ] Update Intune App uninstall command to include reg keys.
- [x] Update code to support latest version of Microsoft.Graph PowerShell module.
- [x] Add functionality to check for Windows Hello for Business login.
- [ ] Remove black window when activating PIM role.
- [ ] Create extend role process.
- [ ] Create deactivate role process.

