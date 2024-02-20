$path1 = Test-Path -Path 'HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'
$path2 = Test-Path -Path 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
$key1 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'
$key2 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'
$key3 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
  
if (($path1 -eq 'TRUE') -AND ($path2 -eq 'TRUE'))
{
    if (($key1.bEnableFlash -eq '0') -AND ($key2.bDisableJavaScript -eq '1') -AND ($key3.bDisableJavaScript -eq '1'))
    {
        Write-Output "Adobe Security Defaults successful"      
        exit 0
    }
    else 
    {
        Write-Output "Keys missing"
        exit 1
    }
}
else
{
    Write-Output "Paths missing"
    exit 1
}