## multiple servers
$SQLServers = (Get-VM -ComputerName HYPERVServer | Where-Object {$_.Name -like '*SQL*' -and $_.State -eq 'Running'}).Name
Get-DbaLastGoodCheckDb -SqlServer $SQLServers  | Out-GridView

