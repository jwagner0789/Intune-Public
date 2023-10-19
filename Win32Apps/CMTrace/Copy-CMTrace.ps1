$PackageName = "CMTrace"

Start-Transcript -Path "C:\Temp\$PackageName-install.log" -Force
$TargetFolder = "C:\Program Files (x86)\CMTrace"
$SourceFolder = $PSScriptRoot

if (!(test-path $TargetFolder))
{
    New-Item -Path $TargetFolder -ItemType Directory -Force
}
$CopyProcess = Copy-Item -Path "$SourceFolder\*" -Destination $TargetFolder -Recurse -Force -ErrorAction Stop

Stop-Transcript
Exit $CopyProcess.ExitCode
