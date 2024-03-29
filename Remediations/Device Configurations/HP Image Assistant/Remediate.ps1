# Folder Directory
$HPIA_folder = "C:\Program Files\HPImageAssistant"
$HPIA_report = "$HPIA_folder\Report"
$HPIA_exe = "$HPIA_folder\HPImageAssistant.exe"
# Software category options: All,BIOS,Drivers,Software,Firmware,Accessories 
# Must match Detection.ps1
$HPIA_category = "Drivers,Software,Accessories"

try
{
    # Runs install process
    Start-Process $HPIA_exe -ArgumentList "/Operation:Analyze /Action:Install /Category:$HPIA_category /Silent /AutoCleanup /reportFolder:""$HPIA_report""" -Wait 
    $HPIA_analyze = Get-Content "$HPIA_report\*.json" | ConvertFrom-Json
    Write-Output "Installation completed: $($HPIA_analyze.HPIA.Recommendations)"
    Exit 0
}
catch
{
    Write-Error $_.Exception
    Exit 1
}