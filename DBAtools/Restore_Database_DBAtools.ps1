#Set Variables

$ScripInfo = '
#######################################################################
#      This script is used to restore database on desired server      # 
#######################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SQLServerName = Read-Host -Prompt "Type sql server where you want to restore database on"
$DatabaseName = Read-Host -Prompt "Type database name which you want to restore. If database exists it will not be overwriten (safty reason)"
$BackupFilePath = Read-Host -Prompt "Type backup path to restore from EX: 'F:\backup\bakupfilename.bak'"
$WhatIF = Read-Host -Prompt "Do you want to use WhatIf (Y/N). If N is specified script will be executed straight away"

If ($WhatIF -match 'N') 
{
    Restore-DbaDatabase -SqlInstance azwewtsqlvm01 -DatabaseName testrestore -Path $BackupFilePath -ReplaceDbNameInFile
    break
}

If ($WhatIF -match 'Y') 
{
     Restore-DbaDatabase -SqlInstance azwewtsqlvm01 -DatabaseName testrestore -Path $BackupFilePath -ReplaceDbNameInFile -WhatIf
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)" 
}
If ($AfterWhatIF -match 'Y')
{
     Write-Host 'Runnin restore database command'
     Restore-DbaDatabase -SqlInstance azwewtsqlvm01 -DatabaseName testrestore -Path $BackupFilePath -ReplaceDbNameInFile
}     
Elseif ($AfterWhatIF -match 'N')
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

