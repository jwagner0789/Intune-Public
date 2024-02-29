function Get-ScriptVersionInfo
{
    Param ([string]$Path)
    $notes = $null
    $notes = @{}
    # Get the .NOTES section of the script header comment.
    $notesText = (Get-Help -Full -Name $Path).alertSet.alert.text
    # Split the .NOTES section by lines.
    $lines = ($notesText -split '\r?\n').Trim()
    # Iterate through every line.
    foreach ($line in $lines)
    {
        if (!$line)
        {
            continue
        }
        $name = $null
        $value = $null

        # Split line by the first colon (:) character.
        if ($line.Contains(':'))
        {
            $nameValue = $null
            $nameValue = @()
            $nameValue = ($line -split ':', 2).Trim()
            $name = $nameValue[0]
            if ($name)
            {
                $value = $nameValue[1]
                if ($value)
                {
                    $value = $value.Trim()
                }
                if (!($notes.ContainsKey($name)))
                {
                    $notes.Add($name, $value)
                }
            }
        }
    }
    return $notes
}

$PSVersion = $PSVersionTable.PSVersion

$Uninstall_HPSupportAssistant = @{
    Name    = "Uninstall-HPSupportAssistant.ps1"
    Version = "1.0.0.0"
}
$ToolKitScripts = @(
    $Uninstall_HPSupportAssistant
)

$PSAppDeployToolKit_Path = "C:\ProgramData\SCONET\PSAppDeployToolkit_v3.9.3"
if (Test-Path $PSAppDeployToolKit_Path)
{
    Write-Output "Current version of PSAppDeployToolkit is installed."
    foreach ($ToolKitScript in $ToolKitScripts)
    {
        if (Test-Path "$PSAppDeployToolKit_Path\ToolKit\$($ToolKitScript.Name)")
        {
            Write-Output "$PSAppDeployToolKit_Path\ToolKit\$($ToolKitScript.Name) exists."
            if ($PSVersion -gt "7.0")
            {
                $ScriptFileInfo = Get-PSScriptFileInfo -Path "$PSAppDeployToolKit_Path\ToolKit\$($ToolKitScript.Name)"
                $ScriptVersion = $ScriptFileInfo.ScriptMetadataComment.Version.Version
            }
            else
            {
                $ScriptFileInfo = Get-ScriptVersionInfo -Path "$PSAppDeployToolKit_Path\ToolKit\$($ToolKitScript.Name)"
                [version]$ScriptVersion = $ScriptFileInfo.Version
            }
            Write-Output "Using PowerShell Version $PSVersion."
            if ($ToolKitScript.Version -gt $ScriptVersion)
            {
                Write-Output "$($ToolKitScript.Name) is out of date."
                exit 1
            }
            
        }
        else
        {
            Write-Output "$PSAppDeployToolKit_Path\ToolKit\$ToolKitScript does not exists."
            exit 1
        }
    }
    exit 0
}
else
{
    Write-Output "PSAppDeployToolkit is not installed."
    exit 1
}