$RegKeyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Autopilot\ComputerRename"
$TaskName = "Autopilot - RenameComputer"
$ScheduledTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$LogFilePath = "C:\ProgramData\RenameComputer\Rename-AutopilotComputer.ps1.log"
$Installed = $false
if (Test-Path $RegKeyPath)
{
    $Value = Get-ItemPropertyValue -Path $RegKeyPath -Name "Status" -ErrorAction SilentlyContinue
    if ($Value -eq "Complete")
    {
        $Installed = $true
        write-host "RegKey"
        exit 0
    }
}
if ($ScheduledTask)
{
    $Installed = $true
    write-host "Scheduled Task"
}
if (Test-Path $LogFilePath)
{
    $LogFileContent = Get-Content -Path $LogFilePath -ErrorAction SilentlyContinue
    if (($LogFileContent -like "*Successfully renamed device in Intune*") -or ($LogFileContent -like "*Successfully renamed computer*") -or ($LogFileContent -like "*Computer name matches Autopilot Device name and Intune Device name.*"))
    {
        $Installed = $true
        write-host "LogFile"
        exit 0
    }
}
if ($Installed -eq $true)
{
    exit 0
}
else
{
    exit 100
}