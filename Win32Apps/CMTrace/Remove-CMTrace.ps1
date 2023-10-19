$PackageName = "CMTrace"

Start-Transcript -Path "C:\Temp\$PackageName-install.log" -Force
$TargetFolder = "C:\Program Files (x86)\CMTrace"

if (test-path $TargetFolder)
{
    $RemoveProcess = Remove-Item -Path $TargetFolder -Recurse -Force -ErrorAction Stop
}

Stop-Transcript
Exit $RemoveProcess.ExitCode
