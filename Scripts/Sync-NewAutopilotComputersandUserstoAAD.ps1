# Forked from https://inittogether.uk/run-aad-connect-delta-sync-when-a-new-device-has-been-added-into-active-directory

param(
    [string]$ComputersOU,
    [string]$UsersOU
)

Import-Module ActiveDirectory

function logwrite
{
    Param ([string]$Logstring)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Logmessage = "$Stamp $Logstring"
    $Logmessage | out-file $Logfile -Append
}

$MaxSize = 5242880
$SyncComputers = $Null
$Date = (get-date).ToString("yyyy-MM")
$Time = [DateTime]::Now.AddMinutes(-5)
$Computers = Get-ADComputer -Filter 'Modified -ge $Time' -SearchBase $ComputersOU -Properties Created, Modified, userCertificate
$Users = Get-ADUser -Filter 'Created -ge $Time' -SearchBase $UsersOU -Properties Created

$Logfile = "C:\Scripts\SyncLog_$Date.log"
if (!(test-path $Logfile))
{
    New-Item -Path $Logfile
}

if ((Get-Item -Path $Logfile).Length -gt $MaxSize)
{
    $Date = ((Get-Date).ToString("yyyy-MM-dd"))
    $Logfile = "C:\Scripts\SyncLog_$Date.log"
    New-Item -Path $Logfile
}

If ($Computers -ne $null) 
{
    ForEach ($Computer in $Computers) 
    {
        $Diff = $Computer.Modified.Subtract($Computer.Created)
        If (($Diff.TotalHours -le 5) -And ($Computer.userCertificate)) 
        {
            # The below adds to AD groups automatically if you want
            #Add-ADGroupMember -Identity "IntuneWindowsUpdatePilotGroup" -Members $computer
            $SyncComputers = "True"
        }
    }
    # Wait for 30 seconds to allow for some replication
    Start-Sleep -Seconds 30
}

If (($SyncComputers -ne $null) -Or ($Users -ne $null)) 
{
    Try 
    {
        Import-Module ADSync
        $ChangeCount = $($Computers.count) + $($Users.count)
        $Sync = Start-ADSyncSyncCycle -PolicyType Delta -erroraction Stop
        if (!$Sync -or $Sync.toString() -eq "Microsoft.IdentityManagement.PowerShell.ObjectModel.SchedulerOperationStatus")
        {
            logwrite "Synchronzied $ChangeCount Users/Computers."
        }
    }
    Catch 
    {
        logwrite "Error: $($_.Exception.Message)"
    }
}
