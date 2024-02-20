$CCMpath = 'C:\Windows\ccmsetup\ccmsetup.exe'
if (Test-Path $CCMpath)
{
    try
    {
        Start-Process -FilePath $CCMpath -Args "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        #$CCMProcess = Get-Process ccmsetup -ErrorAction SilentlyContinue
    }
    catch
    {
        $errMsg = $_.Exception.Message
        Write-Error $errMsg
        exit 1
    }
    finally
    {
        Stop-Service -Name ccmsetup -Force -ErrorAction SilentlyContinue | Out-Null
        Stop-Service -Name CcmExec -Force -ErrorAction SilentlyContinue | Out-Null
        Stop-Service -Name smstsmgr -Force -ErrorAction SilentlyContinue | Out-Null
        Stop-Service -Name CmRcService -Force -ErrorAction SilentlyContinue | Out-Null
 
        Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='ccm'" -Namespace root | Remove-WmiObject -ErrorAction SilentlyContinue | Out-Null
        Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='sms'" -Namespace root\cimv2 | Remove-WmiObject -ErrorAction SilentlyContinue | Out-Null

        $CurrentPath = "HKLM:\SYSTEM\CurrentControlSet\Services"
        if (Test-Path $CurrentPath)
        {
            Remove-Item -Path $CurrentPath\CCMSetup -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\CcmExec -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\smstsmgr -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\CmRcService -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        }

        $CurrentPath = "HKLM:\SOFTWARE\Microsoft"
        if (Test-Path $CurrentPath)
        {
            Remove-Item -Path $CurrentPath\CCM -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\CCMSetup -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\SMS -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\DeviceManageabilityCSP -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        }

        $CurrentPath = $env:WinDir
        if (Test-Path $CurrentPath)
        {
            Remove-Item -Path $CurrentPath\CCM -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\ccmsetup -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\ccmcache -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\SMSCFG.ini -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\SMS*.mif -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $CurrentPath\SMS*.mif -Force -ErrorAction SilentlyContinue  | Out-Null
        }
        Write-Host "Completed"
        exit 0
    }
}
else
{
    Write-Host "Client doesn't exits"
    exit 0
}