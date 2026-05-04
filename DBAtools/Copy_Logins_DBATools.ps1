#Set Variables

$ScripInfo = '
#########################################################################
#   This script is used to copy logins from one sever to another if     #
#   login exists it will not be recreated due to safty reasons          #
#########################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SourceSQLServerName = Read-Host -Prompt "Type sql server where you want to copy login from"
$DestionationSQLServerName = Read-Host -Prompt "Type sql server where you want to copy logins to"
$LoginToCopy = Read-Host -Prompt "Type the login wihch you want to copy: EX sma\username. For multipe logins use , between: EX sma\user1,sma\user2.." 
$LoginToCopy1 = $LoginToCopy.Split(",")

Write-Host 'Starting copy login script'
Copy-DbaLogin -Source $SourceSQLServerName -Destination $DestionationSQLServerName -Login $LoginToCopy1 -Verbose

