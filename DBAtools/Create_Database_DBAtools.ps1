#Set Variables

$ScripInfo = '
#######################################################################
#      This script is used to create database on desired server       # 
#######################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SQLServerName = Read-Host -Prompt "Type sql server where you want to create database on"
$DatabaseName = Read-Host -Prompt "Type type database name"
$WhatIF = Read-Host -Prompt "Do you want to use WhatIf (Y/N). If N is specified script will be executed straight away"

If ($WhatIF -match 'N') 
{
    New-DbaDatabase -SqlInstance $SQLServerName -Name $DatabaseName
    break
}

If ($WhatIF -match 'Y') 
{
    New-DbaDatabase -SqlInstance $SQLServerName -Name $DatabaseName -WhatIf
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)" 
}
If ($AfterWhatIF -match 'Y')
    {
     Write-Host 'Runnin Create database command'
     New-DbaDatabase -SqlInstance $SQLServerName -Name $DatabaseName
     }     
Elseif ($AfterWhatIF -match 'N')
{
    Read-Host -Prompt "Press Enter to exit"
    break
}
