#Set Variables

$ScripInfo = '
#########################################################################
#     This script is used to export and import  database from and on    #
# desired server.Proces is using SQLPackage for export and import action#
#    This sctip can be used for migrating database from newer to older  #
#       version or from Azure SQL database or SQL managed instance.     # 
#########################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SourceSQLServerName = Read-Host -Prompt "Type sql server where you want to export database from"
$SourceDatabaseName = Read-Host -Prompt "Type database name which you want to export"
$ExportFilePath = Read-Host -Prompt "Type path to export database to. It could be local or shared path EX: 'F:\backup\exportfile.bacpac' extension has to be BACPAC"


Write-host 'Running Export script'
Export-DbaDacPackage -SqlInstance $SourceSQLServerName -Database $SourceDatabaseName -FilePath $ExportFilePath -Type Bacpac


#############Import database############

$StartImport = Read-Host -Prompt "Do you want to start import (Y/N)"

if ($StartImport -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}


$DestionationSQLServerName = Read-Host -Prompt "Type sql server where you want to import database to"
$DestinationDatabaseName = Read-Host -Prompt "Type database name which you want to import"


Write-host 'Running Import script'
Publish-DbaDacPackage -SqlInstance $DestionationSQLServerName -Database $DestinationDatabaseName -Path $ExportFilePath -Type bacpac 

