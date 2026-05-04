#Set Variables

$ScripInfo = '
#######################################################################
#      This script is used to backup database on desired server       #
#full backup will be done by default copy only flag is used by default# 
#######################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SQLServerName = Read-Host -Prompt "Type sql server where you want to take database backup on"
$DatabaseName = Read-Host -Prompt "Type database name which you want to backup"
$BackupPath = Read-Host -Prompt "Type path where backup will be located EX: 'F:\backup\'"
$WhatIF = Read-Host -Prompt "Do you want to use WhatIf (Y/N). If N is specified script will be executed straight away"

If ($WhatIF -match 'N') 
{
    Backup-DbaDatabase -SqlInstance $SQLServerName -Database $DatabaseName -Path $BackupPath -Type Full -ReplaceInName -CopyOnly
    break
}

If ($WhatIF -match 'Y') 
{
    Backup-DbaDatabase -SqlInstance $SQLServerName -Database $DatabaseName -Path $BackupPath -Type Full -ReplaceInName -CopyOnly -WhatIf
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)" 
}
If ($AfterWhatIF -match 'Y')
{
     Write-Host 'Runnin backup database command'
     Backup-DbaDatabase -SqlInstance $SQLServerName -Database $DatabaseName -Path $BackupPath -Type Full -ReplaceInName -CopyOnly
}     
Elseif ($AfterWhatIF -match 'N')
{
    Read-Host -Prompt "Press Enter to exit"
    break
}


