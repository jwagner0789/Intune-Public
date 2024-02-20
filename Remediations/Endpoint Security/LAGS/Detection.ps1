$localAdministrators = @()
$memberCount = 0 
# Pulls dsregcmd information
$dsregcmd = dsregcmd /status | Where-Object { $_ -match ' : ' } | ForEach-Object { $_.Trim() } | ConvertFrom-String -PropertyNames 'Name', 'Value' -Delimiter ' : '
# Get device join status
[boolean]$AADJoined = if (($dsregcmd | Where-Object { $_.name -match 'AzureAdJoined' }).value -eq "YES"){$true}else{$false}
[boolean]$DomainJoined = if (($dsregcmd | Where-Object { $_.name -match 'DomainJoined' }).value -eq "YES"){$true}else{$false}
[boolean]$HybridJoined = if ($AADJoined -and $DomainJoined){$true}else{$false}

try
{
    if ($HybridJoined -or $DomainJoined)
    {
        write-host "LAGS-Detect: Hybrid or Domain Joined"
        $numberLocalAdministrators = 6 # Change this based on how many local admins accounts should be there
        # Get local admin group
        $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
        # Get members of Administrators group
        $administratorsGroupMembers = $administratorsGroup.psbase.invoke("Members")
        foreach ($administrator in $administratorsGroupMembers)
        { 
            $localAdministrators += $administrator.GetType().InvokeMember('Name', 'GetProperty', $null, $administrator, $null) 
        }
        # Count how many of the required local admin accounts are in the local admin group
        foreach ($localAdministrator in $localAdministrators)
        { 
            switch ($localAdministrator)
            { 
                "Administrator"
                {
                    $memberCount = $memberCount + 1; break; 
                } 
                "S-1-12-1-552894808-1257906735-3868970431-765332309"
                {
                    $memberCount = $memberCount + 1; break; 
                }
                "S-1-12-1-988282315-1112069411-3191271043-1678955958"
                {
                    $memberCount = $memberCount + 1; break; 
                }
                "<LAPS ACCOUNT>" # Enter name used for LAPS
                {
                    $memberCount = $memberCount + 1; break; 
                }
                "<Domain Local Admin Group>" # If you have a group in your domain that assigns local admins, add it here. If not, remove this switch.
                {
                    $memberCount = $memberCount + 1; break; 
                }
                "Domain Admins"
                {
                    $memberCount = $memberCount + 1; break; 
                }
            } 
        }

        if ($memberCount -eq $numberLocalAdministrators)
        {
            write-host "LAGS-Detect: The required local admins are a match"
            write-host "LAGS-Detect: Member Count: $MemberCount"
            write-host "LAGS-Detect: Number of Local Admins: $numberLocalAdministrators"
            exit 0
        }
        else
        {
            write-host "LAGS-Detect: The number of local administrators don't match."
            write-host "LAGS-Detect: Number of Required Local Admins: $numberLocalAdministrators"
            write-host "LAGS-Detect: Actual Local Admin Count: $MemberCount"
            exit 1
        }
    }
    elseif ($AADJoined -and (-not $HybridJoined -or -not $DomainJoined))
    {
        write-host "LAGS-Detect: AADJoined"
        $numberLocalAdministrators = 3 # Change this based on how many local admins accounts should be there
        # Get local admin group
        $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
        # Get members of Administrators group
        $administratorsGroupMembers = $administratorsGroup.psbase.invoke("Members")
        foreach ($administrator in $administratorsGroupMembers)
        { 
            $localAdministrators += $administrator.GetType().InvokeMember('Name', 'GetProperty', $null, $administrator, $null) 
        }
        # Count how many of the required local admin accounts are in the local admin group
        foreach ($localAdministrator in $localAdministrators)
        { 
            switch ($localAdministrator)
            { 
                "Administrator"
                {
                    $memberCount = $memberCount + 1; break; 
                } 
                "S-1-12-1-552894808-1257906735-3868970431-765332309"
                {
                    $memberCount = $memberCount + 1; break; 
                }
                "S-1-12-1-988282315-1112069411-3191271043-1678955958"
                {
                    $memberCount = $memberCount + 1; break; 
                }
                "<LAPS ACCOUNT>" # Enter name used for LAPS
                {
                    $memberCount = $memberCount + 1; break; 
                }
            } 
        }
        
        if ($memberCount -eq $numberLocalAdministrators)
        {
            write-host "LAGS-Detect:The required local admins are a match"
            write-host "LAGS-Detect:Member Count: $MemberCount"
            write-host "LAGS-Detect:Number of Local Admins: $numberLocalAdministrators"
            exit 0
        }
        else
        {
            write-host "LAGS-Detect:The number of local administrators don't match."
            write-host "LAGS-Detect:Number of Required Local Admins: $numberLocalAdministrators"
            write-host "LAGS-Detect:Actual Local Admin Count: $MemberCount"
            exit 1
        }
    }
}
catch
{
    $errorMessage = $_.Exception.Message
    Write-Error "LAGS-Detect: $errorMessage"
    exit 1
}