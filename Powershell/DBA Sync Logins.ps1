$ExcludedLogins = 'If you want to exlede users'
$AvailabilityGroupName = 'listener name'
$replicas = Get-DbaAgReplica -SqlInstance $AvailabilityGroupName 
$primaryInstance = $replicas | Where Role -eq Primary | select -ExpandProperty name
$secondaryInstances = $replicas | Where Role -ne Primary | select -ExpandProperty name
$erroractionpreference = "Stop"
$sql = "SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled"
$HADR = Invoke-Sqlcmd -Query $sql -ServerInstance $env:computername

if  ( ( $HADR.IsHadrEnabled -eq 1 -and $env:computername -eq $primaryInstance ) -or ( $HADR.IsHadrEnabled -eq 0) ) {
Copy-DbaLogin -Source $primaryInstance -Destination $secondaryInstances -ExcludeSystemLogins 
}
Else {
  write-host("This is secondary replica, coping logins is not allowed")
}

