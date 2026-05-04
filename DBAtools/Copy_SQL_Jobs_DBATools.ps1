#Set Variables

$ScripInfo = '
#########################################################################
#   This script is used to copy SQL jobs from one sever to another if   #
#      job exists it will not be recreated due to safty reasons         #
#########################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SourceSQLServerName = Read-Host -Prompt "Type sql server where you want to copy SQL jobs from"
$DestionationSQLServerName = Read-Host -Prompt "Type sql server where you want to copy SQL jobs to"
$JobsToCopy = Read-Host -Prompt "Type the SQL jobs wihch you want to copy. For multiple SQL jobs use , between: EX job,job1" 
$JobsToCopy1 = $JobsToCopy.Split(",")

Write-Host 'Starting copy jobs script'
Copy-DbaAgentJob -Source $SourceSQLServerName -Destination $DestionationSQLServerName -Job $JobsToCopy1 -Verbose
