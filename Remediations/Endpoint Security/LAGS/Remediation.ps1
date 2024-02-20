# Gets current user
$currentUser = (Get-CimInstance Win32_ComputerSystem).Username -replace '.*\\'
# Pulls dsregcmd information
$dsregcmd = dsregcmd /status | Where-Object { $_ -match ' : ' } | ForEach-Object { $_.Trim() } | ConvertFrom-String -PropertyNames 'Name', 'Value' -Delimiter ' : '
# Get device join status
[boolean]$AADJoined = if (($dsregcmd | Where-Object { $_.name -match 'AzureAdJoined' }).value -eq "YES"){$true}else{$false}
[boolean]$DomainJoined = if (($dsregcmd | Where-Object { $_.name -match 'DomainJoined' }).value -eq "YES"){$true}else{$false}
[boolean]$HybridJoined = if ($AADJoined -and $DomainJoined){$true}else{$false}
$administratorGroupMembersSID = @()

try
{
    if ($HybridJoined -or $DomainJoined)
    {
        write-host "LAGS-Remediate: Hybrid or Domain Joined"
        $localAdministrators = @(
            "S-1-12-1-552894808-1257906735-3868970431-765332309", 
            "S-1-12-1-988282315-1112069411-3191271043-1678955958", 
            "<Domain Local Admin Group>", # If you have a group in your domain that assigns local admins, add it here. If not, remove this line.
            "Domain Admins", 
            "<LAPS ACCOUNT>" # Enter name used for LAPS
        )
        # Get local admin group
        $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
        # Get members of Administrators group not including the current user or the local administrator account
        $administratorsGroupMembers = $administratorsGroup.psbase.invoke("Members")
        foreach ($administratorsGroupMember in $administratorsGroupMembers)
        {
            $administratorsGroupMemberName = $administratorsGroupMember.GetType().InvokeMember('Name', 'GetProperty', $null, $administratorsGroupMember, $null) 
            if (($administratorsGroupMemberName -ne $currentUser) -and ($administratorsGroupMemberName -ne "Administrator"))
            {
                $administratorGroupMembersSID += $administratorsGroupMemberName
            }
        }
        $CompareObject = Compare-Object $localAdministrators $administratorGroupMembersSID  
        foreach ($compare in $CompareObject)
        {
            if ($compare.SideIndicator -eq "<=")
            {
                # Add required local administrators to the local administrator group
                $administratorsGroup.Add("WinNT://$($compare.InputObject)")
                Write-Host "LAGS-Remediate: Successfully added $($compare.InputObject) to Administrators group"
            }
        }
        Write-Host "LAGS-Remediate: Successfully remediated the local administrators"
        exit 0
    }
    elseif ($AADJoined -and (-not $HybridJoined -or -not $DomainJoined))
    {
        write-host "LAGS-Remediate: AADJoined"
        $localAdministrators = @(
            "S-1-12-1-552894808-1257906735-3868970431-765332309", 
            "S-1-12-1-988282315-1112069411-3191271043-1678955958", 
            "<LAPS ACCOUNT>" # Enter name used for LAPS
        )
        # Get local admin group
        $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
        # Get members of Administrators group
        $administratorsGroupMembers = $administratorsGroup.psbase.invoke("Members")
        foreach ($administratorsGroupMember in $administratorsGroupMembers)
        {
            $administratorsGroupMemberName = $administratorsGroupMember.GetType().InvokeMember('Name', 'GetProperty', $null, $administratorsGroupMember, $null) 
            if (($administratorsGroupMemberName -ne $currentUser) -and ($administratorsGroupMemberName -ne "Administrator"))
            {
                $administratorGroupMembersSID += $administratorsGroupMemberName
            }
        }
        $CompareObject = Compare-Object $localAdministrators $administratorGroupMembersSID  
        foreach ($compare in $CompareObject)
        {
            if ($compare.SideIndicator -eq "<=")
            {
                # Add required local administrators to the local administrator group
                $administratorsGroup.Add("WinNT://$($compare.InputObject)")
                Write-Host "LAGS-Remediate: Successfully added $localAdministrator to Administrators group"
            }
        }
        Write-Host "LAGS-Remediate: Successfully remediated the local administrators"
        exit 0
    }
}
catch
{
    $errorMessage = $_.Exception.Message
    Write-Error "LAGS-Detect: $errorMessage"
    exit 1
}