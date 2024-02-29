function Get-ScriptVersionInfo
{
    Param ([string]$Path)
    $notes = $null
    $notes = @{}
    # Get the .NOTES section of the script header comment.
    $notesText = (Get-Help -Full -Name $Path).alertSet.alert.text
    # Split the .NOTES section by lines.
    $lines = ($notesText -split '\r?\n').Trim()
    # Iterate through every line.
    foreach ($line in $lines)
    {
        if (!$line)
        {
            continue
        }
        $name = $null
        $value = $null

        # Split line by the first colon (:) character.
        if ($line.Contains(':'))
        {
            $nameValue = $null
            $nameValue = @()
            $nameValue = ($line -split ':', 2).Trim()
            $name = $nameValue[0]
            if ($name)
            {
                $value = $nameValue[1]
                if ($value)
                {
                    $value = $value.Trim()
                }
                if (!($notes.ContainsKey($name)))
                {
                    $notes.Add($name, $value)
                }
            }
        }
    }
    return $notes
}

$PSVersion = $PSVersionTable.PSVersion
Write-Output "Using PowerShell Version $PSVersion."

if (-not(Test-Path "C:\ProgramData\PSAppDeployToolkit_v3.9.3"))
{
    Try
    {
        #Download a zip file which has other required files from the public repo on github
        Invoke-WebRequest -Uri "https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/releases/download/3.9.3/PSAppDeployToolkit_v3.9.3.zip" -OutFile "C:\ProgramData\PSAppDeployToolkit_v3.9.3.zip"

        #Unblock the files especially since they are download from the internet
        Get-ChildItem "C:\ProgramData\PSAppDeployToolkit_v3.9.3.zip" -Recurse -Force | Unblock-File

        #Unzip the files into the current direectory
        Expand-Archive -LiteralPath "C:\ProgramData\PSAppDeployToolkit_v3.9.3.zip" -DestinationPath "C:\ProgramData\PSAppDeployToolkit_v3.9.3"
        Remove-Item -Path "C:\ProgramData\PSAppDeployToolkit_v3.9.3.zip" -Force
        Write-Output "PSAppDeployToolkit was successfully deployed."
    }
    catch
    {
        Write-Output "PSAppDeployToolkit failed to deploy."
        exit 1
    }
}
try
{
    $PSAppDeployToolKit_Path = "C:\ProgramData\PSAppDeployToolkit_v3.9.3\Toolkit"
    $Uninstall_HPSupportAssistant = @{
        Name    = "Uninstall-HPSupportAssistant"
        Params  = @{
            Version     = "1.0.0.0"
            Author      = "Justin Wagner"
            Description = "Uninstalls HP Support Assistant"
            Path        = "$PSAppDeployToolKit_Path\Uninstall-HPSupportAssistant.ps1"
            CompanyName = "Insert Company Name"
        }
        Content = @'

.DESCRIPTION 
Uninstalls HP Support Assistant 

.NOTES
Version: 1.0.0.0

#> 
Param()
[String]$DeploymentType = 'Uninstall'
[String]$DeployMode = 'NonInteractive'
[switch]$AllowRebootPassThru = $false
[switch]$TerminalServerMode = $false
[switch]$DisableLogging = $false
Try
{
    Try
    {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch
    {
    }
    [String]$appVendor = 'Hewlett-Packard'
    [String]$appName = 'HP Support Assistant'
    [String]$appVersion = '123'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '02/16/2024'
    [String]$appScriptAuthor = 'Justin Wagner'

    [String]$installName = ''
    [String]$installTitle = 'HP Support Assistant'

    [Int32]$mainExitCode = 0

    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    If (Test-Path -LiteralPath 'variable:HostInvocation')
    {
        $InvocationInfo = $HostInvocation
    }
    Else
    {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = "C:\ProgramData\PSAppDeployToolkit_v3.9.3"
    Try
    {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\Toolkit\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf'))
        {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging)
        {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else
        {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch
    {
        If ($mainExitCode -eq 0)
        {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        If (Test-Path -LiteralPath 'variable:HostInvocation')
        {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else
        {
            Exit $mainExitCode
        }
    }
    If ($deploymentType -ieq 'Uninstall')
    {
        [String]$installPhase = 'Pre-Uninstallation'
        Show-InstallationWelcome -CloseApps 'HPSF,WWAHost' -Silent
        [String]$installPhase = 'Uninstallation'
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $HPSAInstall = $Apps | Where-Object { $_.DisplayName -eq "HP Support Assistant" }
        If ($useDefaultMsi)
        {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile)
            {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        If (Test-Path -Path "$envProgramFiles\HP\HP Support Framework\UninstallHPSA.exe")
        {
            Write-Log -Message "Uninstalling the HP Support Assistant (Version 9) from $envProgramFiles."
            Execute-Process -Path "$envProgramFiles\HP\HP Support Framework\UninstallHPSA.exe" -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`"" -WindowStyle Hidden -ContinueOnError $true -ExitOnProcessFailure $false
            Start-Sleep -Seconds 5 
            if (Test-Path -Path "$envProgramFiles\HP\HP Support Framework")
            {
                Remove-Item -Path "$envProgramFiles\HP\HP Support Framework" -Force -Recurse
            }
        }
        If (Test-Path -Path "$envProgramFilesX86\HP\HP Support Framework\UninstallHPSA.exe")
        {
            Write-Log -Message "Uninstalling the HP Support Assistant (Version 9) from $envProgramFilesX86."
            Execute-Process -Path "$envProgramFilesX86\HP\HP Support Framework\UninstallHPSA.exe" -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`"" -WindowStyle Hidden -ContinueOnError $true -ExitOnProcessFailure $false
            Start-Sleep -Seconds 5
            if (Test-Path -Path "$envProgramFilesX86\HP\HP Support Framework")
            {
                Remove-Item -Path "$envProgramFilesX86\HP\HP Support Framework" -Force -Recurse
            }
        }
        If (Test-Path -Path "$envProgramFiles\Hewlett-Packard\HP Support Framework\UninstallHPSA.exe")
        {
            Write-Log -Message "Uninstalling the HP Support Assistant (Version 8) from $envProgramFiles." 
            Execute-Process -Path "$envProgramFiles\Hewlett-Packard\HP Support Framework\UninstallHPSA.exe" -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`"" -WindowStyle Hidden -ContinueOnError $true -ExitOnProcessFailure $false
            Start-Sleep -Seconds 5
            if (Test-Path -Path "$envProgramFiles\Hewlett-Packard\HP Support Framework")
            {
                Remove-Item -Path "$envProgramFiles\Hewlett-Packard\HP Support Framework" -Force -Recurse
            }
        }
        If (Test-Path -Path "$envProgramFilesX86\Hewlett-Packard\HP Support Framework\UninstallHPSA.exe")
        {
            Write-Log -Message "Uninstalling the HP Support Assistant (Version 8) from $envProgramFilesX86."
            Execute-Process -Path "$envProgramFilesX86\Hewlett-Packard\HP Support Framework\UninstallHPSA.exe" -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`"" -WindowStyle Hidden -ContinueOnError $true -ExitOnProcessFailure $false
            Start-Sleep -Seconds 5
            if (Test-Path -Path "$envProgramFilesX86\Hewlett-Packard\HP Support Framework")
            {
                Remove-Item -Path "$envProgramFilesX86\Hewlett-Packard\HP Support Framework" -Force -Recurse
            }
        }
        Remove-MSIApplications -Name 'HP Support Assistant'
        Remove-MSIApplications -Name 'HP Support Solutions Framework'
        [String]$installPhase = 'Post-Uninstallation'
        foreach ($HPSA in $HPSAInstall)
        {
            $HPSAInstallLocation = $HPSA.InstallLocation
            $HPSARegKeyPath = $HPSA.PSPath
            if (Test-Path $HPSARegKeyPath)
            {
                Remove-Item $HPSARegKeyPath -Force -Recurse
            }
        }
    }
    Exit-Script -ExitCode $mainExitCode
}
Catch
{
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
'@
    }
    $PowerShellScriptData = @(
        $Uninstall_HPSupportAssistant
    )
    foreach ($Item in $PowerShellScriptData)
    {
        [String]$ScriptPath = $($Item.Params.Path)
        [Version]$ScriptVersion = $Item.Params.Version
        if (-not (Test-Path $ScriptPath))
        {
            New-ScriptFileInfo -Path $ScriptPath -Author $($Item.Params.Author) -Description $($Item.Params.Description) -CompanyName $($Item.Params.CompanyName) -Version $ScriptVersion -Force
            while ((Get-Content $ScriptPath | Select-Object -Last 1) -ne "<# ")
            {
                Get-Content $ScriptPath | Select-Object -SkipLast 1 | Set-Content "$ScriptPath-Update.ps1"
                Get-Content "$ScriptPath-Update.ps1" | Set-Content $ScriptPath -Force
                Remove-Item -Path "$ScriptPath-Update.ps1"
            }
            Add-Content -Path $ScriptPath -Value $($Item.Content)
            Write-Output "Created $($Item.Name).ps1"
        }
        else
        {
            if ($PSVersion -gt "7.0")
            {
                $ScriptFileInfo = Get-PSScriptFileInfo -Path $ScriptPath
                $CurrentScriptVersion = $ScriptFileInfo.ScriptMetadataComment.Version.Version
            }
            else
            {
                $ScriptFileInfo = Get-ScriptVersionInfo -Path $ScriptPath
                [version]$CurrentScriptVersion = $ScriptFileInfo.Version
            }
            if ($ScriptVersion -gt $CurrentScriptVersion)
            {
                New-ScriptFileInfo -Path $ScriptPath -Author $($Item.Params.Author) -Description $($Item.Params.Description) -CompanyName $($Item.Params.CompanyName) -Version $ScriptVersion -Force
                while ((Get-Content $ScriptPath | Select-Object -Last 1) -ne "<# ")
                {
                    Get-Content $ScriptPath | Select-Object -SkipLast 1 | Set-Content "$ScriptPath-Update.ps1"
                    Get-Content "$ScriptPath-Update.ps1" | Set-Content $ScriptPath -Force
                    Remove-Item -Path "$ScriptPath-Update.ps1"
                }
                Add-Content -Path $ScriptPath -Value $($Item.Content)
                Write-Output "Updated $($Item.Name).ps1"
            }
            else
            {
                Write-Output "$($Item.Name).ps1 version is up to date."
            }
        }
    }
    exit 0
}
catch
{
    Write-Output "Failed to create PowerShell content for PSAppDeployToolKit"
    Write-Error $_
    exit 1
}