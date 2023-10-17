$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$DesktopPath = "$DesktopPath\OneDrive.lnk"
$onedrivepath = "https://### Insert Tenant Name ###.sharepoint.com/personal/" + ($((get-aduser -Identity $env:username).userprincipalname)).replace(".","_").replace("@","_") + "/_layouts/15/onedrive.aspx/sc.ohio.gov"
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut($DesktopPath)
$shortcut.TargetPath = $onedrivepath
if (test-path "C:\users\$env:username\temp")
{
    if (!(test-path "C:\users\$env:username\temp\OneDrive.png"))
    {
        Copy-Item -Path "### Insert path to OneDrive .ico file ###" -Destination "C:\users\$env:username\temp"
    }
}
else
{
    new-item -Path "C:\users\$env:username\temp" -ItemType Directory
    Copy-Item -Path "### Insert path to OneDrive .ico file ###" -Destination "C:\users\$env:username\temp"
}
$shortcut.IconLocation = "C:\users\$env:username\temp\OneDrive.ico"
$shortcut.Save()
