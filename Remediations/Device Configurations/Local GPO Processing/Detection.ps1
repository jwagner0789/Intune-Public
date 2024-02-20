$path = "Registry::HKLM\Software\Policies\Microsoft\Windows\System"

try
{
    $value = Get-ItemPropertyValue -Path $path -Name DisableLGPOProcessing -ErrorAction Stop
    if ($value -eq 1)
    {
        write-host "Reg key value is correct: $value"
        exit 0
    }
    else
    {
        write-host "Reg key value is not correct: $value"
        exit 1
    }
}
catch
{
    Write-Host "Reg key does not exist: $path"
    exit 1
}

