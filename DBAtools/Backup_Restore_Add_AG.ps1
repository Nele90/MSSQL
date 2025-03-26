#Declare variables!!
$Source = 'InsanceName'
$Destination = 'InstanceName'
$BackupDB = 'Stash'
$RestoreDB = 'Stash'
$SourceComputerName = "InstanceName" 
$SourceDriveLetter = "E"
$SourcePath = "DatabaseName"
$DestinationComputerName = $Destination
$DestinationDriveLetter = "D"
$DestinationPath = "DatabaseName"
$LocallBackup = $SourceDriveLetter + ':'+ $SourcePath
$LocalRestore = $DestinationDriveLetter + ':'+ $DestinationPath
$SourceSQLVersion = Invoke-DbaQuery -SqlInstance $Source -Query "SELECT SUBSTRING(CAST(SERVERPROPERTY('productversion') AS varchar(30)), 1, 2)" | Select-Object | ForEach-Object {$_.Column1}
$DestinationSQLVersion = Invoke-DbaQuery -SqlInstance $Destination -Query "SELECT SUBSTRING(CAST(SERVERPROPERTY('productversion') AS varchar(30)), 1, 2)" | Select-Object | ForEach-Object {$_.Column1}

if ($SourceSQLVersion -le $DestinationSQLVersion)
{

        #Redis_security
                                                                                     
        #get dataase size and name 
        #Get-DbaDatabase -SqlInstance $Source | Select Name, SizeMB | Format-Wide
        #check disk space on source and dest servers
        #Get-DbaDiskSpace -ComputerName $source
        #Get-DbaDiskSpace -ComputerName $Destination
        New-Item -Path \\$SourceComputerName\$SourceDriveLetter$\$SourcePath -ItemType directory 
        New-Item -Path \\$DestinationComputerName\$DestinationDriveLetter$\$DestinationPath -ItemType directory


        #check if folder is created on source/destanation server of not then run New-Itme line
        #Get-ChildItem -Path \\$SourceComputerName\$SourceDriveLetter$\$SourcePath 
        #Get-ChildItem -Path \\$DestinationComputerName\$DestinationDriveLetter$\$DestinationPath

        #backup db
        Backup-DbaDatabase -SqlInstance $Source -Path $LocallBackup  -Database $BackupDB -Type Full -CopyOnly -CompressBackup -IgnoreFileChecks -Verbose


        #copy backup file/s using robocopy, or some other option, copy-itme and copy-file can be used if robo copy does not work!!
        $backupfilecopy = Get-ChildItem -Path \\$SourceComputerName\$SourceDriveLetter$\$SourcePath | sort -Descending lastwritetime | Select name -First 1 | Where-Object Name -like "$BackupDB*" |  Select-Object | ForEach-Object {$_.Name}
        $src = "\\$SourceComputerName\$SourceDriveLetter$\$SourcePath\"
        $dst = "\\$DestinationComputerName\$DestinationDriveLetter$\$DestinationPath"
        $backupfilecopy

        ROBOCOPY $src $dst $backupfilecopy /COPY:DAT /MT:4 /R:1 


        $backupfiletorestore = Get-ChildItem -Path \\$DestinationComputerName\$DestinationDriveLetter$\$DestinationPath | sort -Descending lastwritetime | Where-Object Name -like "$BackupDB*" | Select name -First 1 | Select-Object | ForEach-Object {$_.Name}
        $restorefromlocal = "$LocalRestore\$backupfiletorestore"
        $AGname = Get-DbaAvailabilityGroup -SqlInstance $Destination | select AvailabilityGroup | Select-Object | ForEach-Object {$_.AvailabilityGroup}
        $Listener = Get-DbaAgListener -SqlInstance $Destination | Select-Object | ForEach-Object {$_.name}
        $replicas = Get-DbaAgReplica -SqlInstance $Listener 
        $primaryInstance = $replicas | Where Role -eq Primary | select -ExpandProperty name
        $secondaryInstances = $replicas | Where Role -ne Primary | select -ExpandProperty name

        $CheckIfIs = Get-DbaInstanceProperty -SqlInstance $Destination | Select name, value | Where-Object { $_.name -EQ "IsHadrEnabled" -and $_.value -eq "ture"} | Select-Object | ForEach-Object {$_.Value} 
        if ($CheckIfIs -eq "true" )
        {
                #Restore database 
                Restore-DbaDatabase -SqlInstance $primaryInstance -Path "$restorefromlocal" -DatabaseName $RestoreDB -Verbose
                Add-DbaAgDatabase -SqlInstance $primaryInstance -AvailabilityGroup $AGname -Database $RestoreDB -SeedingMode Automatic -Verbose 


        }
        else 
        {
                Restore-DbaDatabase -SqlInstance $Destination -Path $restorefromlocal -DatabaseName $RestoreDB -Verbose

        }
 

        #add db to ag if needed
        #Get-DbaDatabase -SqlInstance $Destination | Where-Object Name -EQ $RestoreDB | Select Name, SizeMb | Format-Table

        #Remove-DbaDatabase -SqlInstance InstanceName -Database tcprd_poolmgr_old
        #if db is in AG then firs remove it from AG and then drop it
        #Remove-DbaAgDatabase -SqlInstance $Destination -Database $RestoreDB 
        #remove db
        #Remove-DbaDatabase -SqlInstance InstanceName -Database $RestoreDB 


        #remove backup folder!!CHeck what will be deleted before running it!!!!
        Remove-Item -Path \\$SourceComputerName\$SourceDriveLetter$\$SourcePath\ -Verbose

        Remove-Item -Path \\$DestinationComputerName\$DestinationDriveLetter$\$DestinationPath\ -Verbose



}
else 
{
        Write-Host "Backup and restore is not possible, use .bapac instead"
}