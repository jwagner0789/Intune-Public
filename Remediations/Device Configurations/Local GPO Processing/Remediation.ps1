$path = "Registry::HKLM\Software\Policies\Microsoft\Windows\System"

try
{
    Set-ItemProperty -Path $path -name DisableLGPOProcessing -value 1 -ErrorAction stop
    get-itemproperty -path $path -Name DisableLGPOProcessing -ErrorAction stop
    exit 0
}
catch
{
    write-host "Failed to set reg key value."
    exit 1
}