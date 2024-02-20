$LAPSEnabled = @()
$LAPSDisabled = @()

# Gets all Registered Devices
$AllDevices = Get-MgDevice -all | Where-Object {$_.IsManaged -eq $true} | Where-Object {$_.ProfileType -eq "RegisteredDevice"}

# Properties to report on
$Properties = "ApproximateLastSignInDateTime", 
              "DeviceId", 
              "DisplayName", 
              "ID",
              "IsCompliant",
              "IsManaged",
              "ProfileType",
              @{Name="createdDateTime";      Expression={ $_.AdditionalProperties.createdDateTime}},
              @{Name="registrationDateTime"; Expression={ $_.AdditionalProperties.registrationDateTime}},
              @{Name="deviceOwnership"; Expression={ $_.AdditionalProperties.deviceOwnership}},
              @{Name="enrollmentType"; Expression={ $_.AdditionalProperties.enrollmentType}},
              @{Name="managementType"; Expression={ $_.AdditionalProperties.managementType}}

# Filter via Device Ownership. Probably should do this in the Get-MgDevice call
$AllDevices = $AllDevices | Select-Object $Properties | Where-Object {$_.deviceOwnership -eq "Company"}             

# Get all LAPS enabled devices
$LAPS = Get-LapsAADPassword -DeviceIds $AllDevices.DeviceId -ErrorAction Stop

# Compare LAPS enabled devices to all devices list
$Compare = Compare-Object $LAPS.DeviceId $AllDevices.DeviceId -IncludeEqual
foreach ($C in $Compare)
{
    if ($C.SideIndicator -eq "==")
    {
        $LAPSEnabled += Get-MgDevice -Search "DeviceID:$($C.InputObject)" -ConsistencyLevel eventual | Select-Object $Properties
    }
    elseif ($C.SideIndicator -eq "=>")
    {
        $LAPSDisabled += Get-MgDevice -Search "DeviceID:$($C.InputObject)" -ConsistencyLevel eventual | Select-Object $Properties
    }
}