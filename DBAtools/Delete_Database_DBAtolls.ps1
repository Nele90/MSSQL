#Set Variables

$ScripInfo = '
#######################################################################
#      This script is used to delete database on desired server       # 
#######################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SQLServerName = Read-Host -Prompt "Type sql server where you want to delete database on"
$DatabaseName = Read-Host -Prompt "Type database name which need to be deleted"
$WhatIF = Read-Host -Prompt "Do you want to use WhatIf (Y/N). If N is specified script will be executed straight away"

If ($WhatIF -match 'N') 
{
    Remove-DbaDatabase -SqlInstance $SQLServerName -Database $DatabaseName
    break
}

If ($WhatIF -match 'Y') 
{
    Remove-DbaDatabase -SqlInstance $SQLServerName -Database $DatabaseName -WhatIf
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)" 
}
If ($AfterWhatIF -match 'Y')
{
     Write-Host 'Runnin Drop database command'
    Remove-DbaDatabase -SqlInstance $SQLServerName -Database $DatabaseName
}     
Elseif ($AfterWhatIF -match 'N')
{
    Read-Host -Prompt "Press Enter to exit"
    break
}



