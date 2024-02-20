# Folder Directory
$HPIA_folder = "C:\Program Files\HPImageAssistant"
$HPIA_reco = "$HPIA_folder\Recommendations"
$HPIA_exe = "$HPIA_folder\HPImageAssistant.exe"
# Software category options: All,BIOS,Drivers,Software,Firmware,Accessories
$HPIA_category = "Drivers,Software,Accessories" 

Try
{
    if ([System.IO.File]::Exists($HPIA_exe))
    {
        # Removes potentially outdated recommendations
        if (Test-Path $HPIA_reco)
        {
            Remove-Item $HPIA_reco -Recurse -Force
        }

        # Starts process to pull current recommendations
        Start-Process $HPIA_exe -ArgumentList "/Operation:Analyze /Category:$HPIA_category /Action:List /Silent /ReportFolder:""$HPIA_reco""" -Wait
        
        # Checks if there are new recommnedations
        $HPIA_analyze = Get-Content "$HPIA_reco\*.json" | ConvertFrom-Json
        if ($HPIA_analyze.HPIA.Recommendations.count -lt 1)
        {
            Write-Output "Compliant, no drivers needed"
            Exit 0
        }
        else
        {
            Write-Warning "Found drivers to download/install: $($HPIA_analyze.HPIA.Recommendations)"
            Exit 1
        }
    }
    else
    {
        Write-Error "HP Image Assistant missing"
        Exit 1
    }
} 
Catch 
{
    Write-Error $_.Exception
    Exit 1
}
