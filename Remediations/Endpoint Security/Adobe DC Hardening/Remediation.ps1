$path1 = 'HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'
$path2 = 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
 
try
{
    New-item -Path $path1 -Force
    New-ItemProperty -Path $path1 -Name 'bEnableFlash' -Value 0 -PropertyType DWord -Force
    New-ItemProperty -Path $path1 -Name 'bDisableJavaScript' -Value 1 -PropertyType DWord -Force
    New-item -Path $path2 -Force
    New-ItemProperty -Path $path2 -Name 'bDisableJavaScript' -Value 1 -PropertyType DWord -Force
    exit 0
}
catch
{
    $errMsg = $_.Exception.Message
    Write-host $errMsg
    exit 1
}