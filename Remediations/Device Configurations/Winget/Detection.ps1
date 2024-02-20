#Create path and define log file
$path = "C:\ProgramData\WinGet"
mkdir $path -ErrorAction SilentlyContinue

#Check if WinGet is Installed
$TestPath = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.21.3482.0_x64__8wekyb3d8bbwe\AppxSignature.p7x"
$Winget = Test-path $TestPath -PathType Leaf

#Install WinGet
if (!$Winget)
{
    write-host "WinGet is not installed"
    exit 1
}
Else
{
    write-host "WinGet is installed"
    exit 0
}