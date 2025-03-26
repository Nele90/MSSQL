CREATE PROCEDURE [dbo].[usp_GenerateRestoreScripts] @DBname VARCHAR(100)
AS

SET NOCOUNT ON-- required because we're going to print T-SQL for the restores in the messages 'tab' of SSMS

/* 
Script creates the T-SQL to restore a database with info from MSDB
It helps by creating RESTORE command constructed from the last FULL backup, the last DIFFERENTIAL backup
and all the required TRANSACTION LOG backups after this.
Neat when you have a high frequency of differential or log backups

The variable @DBName should be set to the name of the database you want to restore.

!!! BE AWARE: include MSDB in your backup plan for this T-SQL script to work in all circumstances !!!
I usually include MSDB in the log backup schedule (set the db to full recovery mode)

*/
DECLARE @lastFullBackup INT, @lastFullBackupPath VARCHAR(2000), @lastDifferentialBackup INT, @lastDifferentialBackupPath VARCHAR(2000)
DECLARE @i INT, @logBackupPath VARCHAR(1000)

-- remove temp object that might exist
IF OBJECT_ID('tempdb..#MSDBBackupHistory') IS NOT NULL
    DROP TABLE #MSDBBackupHistory

CREATE TABLE #MSDBBackupHistory (
    id INT IDENTITY(1,1),
    backup_start_date DATETIME,
    backup_type CHAR(1),
    physical_device_name VARCHAR(1000))

INSERT INTO #MSDBBackupHistory (backup_start_date,  backup_type, physical_device_name)
    SELECT BS.backup_start_date, BS.type, RTRIM(BMF.physical_device_name)
    FROM msdb..backupset BS JOIN msdb..backupmediafamily BMF ON BMF.media_set_id=BS.media_set_id
    WHERE BS.database_name = @DBName
    ORDER BY BS.backup_start_date -- dump the last backup first in table

-- get the last Full backup info.
SET @lastFullBackup = (SELECT MAX(id) FROM #MSDBBackupHistory WHERE backup_type='D')
SET @lastFullBackupPath = (SELECT physical_device_name FROM #MSDBBackupHistory WHERE id=@lastFullBackup)

-- Restore the Full backup
PRINT 'RESTORE DATABASE ' + @DBName
PRINT 'FROM DISK=''' + @lastFullBackupPath + ''''

-- IF it's there's no backup (differential or log) after it, we set to 'with recovery'
IF (@lastFullBackup = (SELECT MAX(id) FROM #MSDBBackupHistory))
    PRINT 'WITH RECOVERY'
ELSE PRINT 'WITH NORECOVERY'

PRINT 'GO'
PRINT ''

-- get the last Differential backup (it must be done after the last Full backup)
SET @lastDifferentialBackup = (SELECT MAX(id) FROM #MSDBBackupHistory WHERE backup_type='I' AND id > @lastFullBackup)
SET @lastDifferentialBackupPath = (SELECT physical_device_name FROM #MSDBBackupHistory WHERE id=@lastDifferentialBackup)

-- when there's a differential backup after the last full backup create the restore T-SQL commands
IF (@lastDifferentialBackup IS NOT NULL)
BEGIN
    -- Restore last diff. backup
    PRINT 'RESTORE DATABASE ' + @DBName
    PRINT 'FROM DISK=''' + @lastDifferentialBackupPath + ''''

    -- If no backup made (differential or log) after it, set to 'with recovery'
    IF (@lastDifferentialBackup = (SELECT MAX(id) FROM #MSDBBackupHistory))
        PRINT 'WITH RECOVERY'
    ELSE PRINT 'WITH NORECOVERY'

    PRINT 'GO'
    PRINT '' -- new line for readability
END

-- construct the required TRANSACTION LOGs restores
IF (@lastDifferentialBackup IS NULL) -- no diff backup made?
    SET @i = @lastFullBackup + 1    -- search for log dumps after the last full
ELSE SET @i = @lastDifferentialBackup + 1 -- search for log dumps after the last diff

-- script T-SQL restore commands from the log backup history
WHILE (@i <= (SELECT MAX(id) FROM #MSDBBackupHistory))
BEGIN
    SET @logBackupPath = (SELECT physical_device_name FROM #MSDBBackupHistory WHERE id=@i)
    PRINT 'RESTORE LOG ' + @DBName
    PRINT 'FROM DISK=''' + @logBackupPath + ''''

    -- it's the last transaction log, set to 'with recovery'
    IF (@i = (SELECT MAX(id) FROM #MSDBBackupHistory))
        PRINT 'WITH RECOVERY'
    ELSE PRINT 'WITH NORECOVERY'   

    PRINT 'GO'
    PRINT '' -- new line for readability

    SET @i = @i + 1 -- try to find the next log entry
END

-- remove temp objects that exist
IF OBJECT_ID('tempdb..#MSDBBackupHistory') IS NOT NULL
    DROP TABLE #MSDBBackupHistory