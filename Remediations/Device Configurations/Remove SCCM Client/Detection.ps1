$CCMpath = 'C:\Windows\ccmsetup\ccmsetup.exe'
if (Test-Path $CCMpath)
{
    write-host "Client exists."
    exit 1
}
else
{
    write-host "Client does not exist."
    exit 0
}
