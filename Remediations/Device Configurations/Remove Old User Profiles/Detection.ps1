function Get-CurrentUser
{
    $Users = query user
    $Users = $Users | ForEach-Object { (($_.trim() -replace ">" -replace "(?m)^([A-Za-z0-9]{3,})\s+(\d{1,2}\s+\w+)", '$1  none  $2' -replace "\s{2,}", "," -replace "none", $null)) } | ConvertFrom-Csv
    foreach ($User in $Users)
    {
        if ($User.STATE -eq "Active")
        {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Username     = $User.USERNAME
                SessionState = $User.STATE.Replace("Disc", "Disconnected")
                SessionType  = $($User.SESSIONNAME -Replace '#', '' -Replace "[0-9]+", "")
            }
        } 
    }
}

$Profile_age = 60 # max profile age in days
Try
{
    # Get all User profile folders older than X days
    $LastAccessedFolder = Get-ChildItem "C:\Users" |  Where-Object { $_ -notlike "*Windows*" -and $_ -notlike "*default*" -and $_ -notlike "*Public*" -and $_ -notlike "*Admin*" } | Where-Object LastWriteTime -lt (Get-Date).AddDays(-$Profile_age)
    # Filter the list of folders to only include those that are not associated with local user accounts
    $Profiles_notLocal = $LastAccessedFolder | Where-Object { $_.Name -notin $(Get-LocalUser).Name }
    # Retrieve a list of user profiles and filter to only include the old ones
    $Profiles_2remove = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath -in $($Profiles_notLocal.FullName) }
    if ($Profiles_2remove)
    {
        foreach ($Profile in $Profiles_2remove.localpath)
        {
            $profile_user = Get-ADUser -identity $Profile.replace("C:\Users\", "") | Select-Object surname, givenname
            $currentuser = Get-ADUser -identity ((Get-CurrentUser).UserName).replace(".$env:USERDOMAIN","") | Select-Object surname, givenname
            if (($currentuser.surname -ne $profile_user.surname) -and ($currentuser.givenname -ne $profileuser.givenname))
            {
                Write-Warning "Old profiles ($Profile_age days+): $($Profile)"
                Exit 1
            }
        }
    }
    else
    {
        Write-Output "No profiles older than $Profile_age days found. "
        Exit 0
    }
} 
Catch
{
    Write-Error $_
}