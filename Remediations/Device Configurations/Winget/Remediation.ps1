#Create path and define log file
$path = "C:\ProgramData\WinGet"
mkdir $path -ErrorAction SilentlyContinue

#Check if WinGet is Installed
$TestPath = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.21.3482.0_x64__8wekyb3d8bbwe\AppxSignature.p7x"
$Winget = Test-path $TestPath -PathType Leaf

#Install WinGet
if (!$Winget)
{
    Try
    {
        Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile "$path\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile "$path\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile "$path\Microsoft.UI.Xaml.2.7.x64.appx"
        Add-AppxProvisionedPackage -online -packagepath $path\Microsoft.VCLibs.x64.14.00.Desktop.appx -SkipLicense
        Add-AppxProvisionedPackage -online -packagepath $path\Microsoft.UI.Xaml.2.7.x64.appx -SkipLicense
        Add-AppxProvisionedPackage -online -packagepath $path\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -SkipLicense
        write-host "WinGet was installed."
        exit 0
    }
    Catch
    {
        Write-host "WinGet failed to install."
        exit 1
    }
}
Else
{
    write-host "WinGet is installed"
    exit 0
}