#Set Variables

$ScripInfo = '
#######################################################################
#  This script is used to backup and restore database between servers #
#  or localy on one server. Backup is done with CopyOnly by default   #
#  restoring database is possbile with new database file locaton.     #
#  Before run it on production pelase test on test environemnt.       #
#  Fell free to change the script accordingly.!                       # 
#######################################################################'

Write-host $ScripInfo

$StartScript = Read-Host -Prompt "Do you want to start the script (Y/N)"

if ($StartScript -match 'N') 
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

$SourceServer = Read-Host -Prompt "Type source server name where you want to take backup from"
$SourceDatabaseName = Read-Host -Prompt "Type source database name which you want to backup-restore"
$BackupType = Read-Host -Prompt "Type which backup type would you like to do: Full, Log, Differential"
$SharedPath = Read-Host -Prompt 'Type shared path where your backup will be done, both servers should have access to that path! ex: "\\servername\TestSHare\"'
$BackupFileName = Read-Host -Prompt "Type bakup name ex: yourdatabase.bak"
$WhatIF = Read-Host -Prompt "Do you want to use WhatIf (Y/N)"
$BackupCodeBaseNoWhatIf = New-Object PSObject -Property @{
    sqlinstance = $SourceServer
    Database = $SourceDatabaseName
    Path = $SharedPath
    FilePath = $BackupFileName
    CopyOnly = 'CopyOnly'
    BackupType = $BackupType
    Confrim = 'cf'

}


$BackupCodeBaseWithWhatIf = New-Object PSObject -Property @{
    sqlinstance = $SourceServer
    Database = $SourceDatabaseName
    Path = $SharedPath
    FilePath = $BackupFileName
    CopyOnly = 'CopyOnly'
    BackupType = $BackupType
    WhatIF = 'WhatIf'
}

$CodeWhatIf = "Backup-DbaDatabase -sqlinstance $($BackupCodeBaseWithWhatIf.sqlinstance) -Database $($BackupCodeBaseWithWhatIf.Database) -Path $($BackupCodeBaseWithWhatIf.Path) -FilePath $($BackupCodeBaseWithWhatIf.FilePath) -Type $($BackupCodeBaseWithWhatIf.BackupType) -$($BackupCodeBaseWithWhatIf.CopyOnly) -$($BackupCodeBaseWithWhatIf.WhatIF)"
$CodeWihtNoWhatif = "Backup-DbaDatabase -sqlinstance $($BackupCodeBaseNoWhatIf.sqlinstance) -Database $($BackupCodeBaseNoWhatIf.Database) -Path $($BackupCodeBaseNoWhatIf.Path) -FilePath $($BackupCodeBaseNoWhatIf.FilePath) -Type $($BackupCodeBaseNoWhatIf.BackupType) -$($BackupCodeBaseNoWhatIf.CopyOnly) -$($BackupCodeBaseNoWhatIf.Confrim)"


if ($WhatIF -match 'N') {

    Write-Host 'Runnin Backup script'
    $CodeWihtNoWhatif = " Backup-DbaDatabase -sqlinstance $($BackupCodeBaseNoWhatIf.sqlinstance) -Database $($BackupCodeBaseNoWhatIf.Database) -Path $($BackupCodeBaseNoWhatIf.Path) -Type $($BackupCodeBaseNoWhatIf.BackupType) -$($BackupCodeBaseNoWhatIf.cf) -$($BackupCodeBaseNoWhatIf.CopyOnly)"
    Invoke-Expression $CodeWihtNoWhatif | Out-String -OutVariable out 
}


if ($WhatIF -match 'Y') {
    Invoke-Expression $CodeWhatIf | Out-String -OutVariable out
    $AfterWhatIF = Read-Host -Prompt "Does WhatIf look correcrt, do you want to continue?(Y/N)" 
   If ($AfterWhatIF -match 'Y')
    {
     Write-Host 'Runnin Backup script'
     Invoke-Expression $CodeWihtNoWhatif | Out-String -OutVariable out
     }
     Elseif ($AfterWhatIF -match 'N')
     {
    Read-Host -Prompt "Press Enter to exit"
    break
     }
}
###########################Restore Database to destination server#################################

Write-host 'Run Restore process'
$DestinationServer = Read-Host -Prompt "Type destination server name where you want to restore db to"
$DestinationDatabaseName = Read-Host -Prompt "Type destnation database name"

#formating backup path for restore process
$BackupFormat = $SharedPath.TrimEnd('"')
$BackupPath = $BackupFormat+ $BackupFileName + '"'


$RestoreParameters = New-Object PSObject -Property @{
    sqlinstance = $DestinationServer
    Database = $DestinationDatabaseName
    Path = $BackupPath
}

$RestoreComandBase = 'Restore-DbaDatabase -sqlinstance ' + $($RestoreParameters.sqlinstance) + ' -Database ' + $($RestoreParameters.Database)  + ' -Path ' + $($RestoreParameters.Path) + ' -ReplaceDbNameInFile' + ' -cf'



$DestinationDataLogDirectory = Read-Host -Prompt "Do you want to change default data and log location (Y/N)"

IF ($DestinationDataLogDirectory -match 'Y')
{
$NewDestinationDataDirectory = Read-Host -Prompt "Type new data file location ex: ""G:\Data"""
$NewDestinationLogDirectory = Read-Host -Prompt "Type new log file location ex: ""F:\Data"""
$RestoreComandBaseNewDBLocation = $RestoreComandBase + ' -DestinationDataDirectory ' + $NewDestinationDataDirectory + ' -DestinationLogDirectory ' + $NewDestinationLogDirectory
}

$WhatIFRestore = Read-Host -Prompt "Do you want to use WhatIf (Y/N)"

IF ($WhatIFRestore  -match 'Y' -and $DestinationDataLogDirectory -match 'Y')
{
Write-host 'Run command with new db location and what if'
$RestoreComandBaseNewDBLocationWF = $RestoreComandBaseNewDBLocation + ' -WhatIf'
Invoke-Expression $RestoreComandBaseNewDBLocationWF | Out-String -OutVariable out 
}
elseif ($WhatIFRestore  -match 'Y' -and $DestinationDataLogDirectory -match 'N')
{
Write-host 'Run command with what if and not cahnge db location'
$RestoreComandBaseWF = $RestoreComandBase + ' -WhatIf'
Invoke-Expression $RestoreComandBaseWF | Out-String -OutVariable out 
}
else
{
Write-host 'Run base command'
Invoke-Expression $RestoreComandBase | Out-String -OutVariable out 
}

$AfterWhatIFRestore = Read-Host -Prompt "Does WhatIf look fine, do you want to continue(Y/N)"

IF ($AfterWhatIFRestore  -match 'Y' -and $DestinationDataLogDirectory -match 'Y')
{
Invoke-Expression $RestoreComandBaseNewDBLocation | Out-String -OutVariable out 
}
elseif ($AfterWhatIFRestore  -match 'Y' -and $DestinationDataLogDirectory -match 'N')
{
Invoke-Expression $RestoreComandBase | Out-String -OutVariable out 
}
else
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

###############Revemo Backup File#####################
#Format Backuip file path for deletition
$RemoveBackupFile = Read-Host -Prompt 'Do you want to remove backup file(Y/N)'
$DeleteBackupFile =  $BackupPath -replace '"'

if ($RemoveBackupFile -match 'N')
{
    Read-Host -Prompt "Press Enter to exit"
    break
}

if ($RemoveBackupFile -match 'Y')
{
$DeleteWhatIf = Read-Host -Prompt "Do you want to use WhatIf (Y/N)"
Remove-Item $DeleteBackupFile -WhatIf -Verbose  | Out-String -OutVariable out 
}
$AfterWhatIFRestore = Read-Host -Prompt "Does WhatIf look fine, do you want to continue(Y/N)"
if ($AfterWhatIFRestore -match 'Y')
{
Remove-Item $DeleteBackupFile -Verbose  | Out-String -OutVariable out 
}
