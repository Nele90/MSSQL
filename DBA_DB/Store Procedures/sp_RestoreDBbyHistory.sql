USE [DBA_DB]
GO

/****** Object:  StoredProcedure [dbo].[sp_RestoreDBbyHistory]    Script Date: 25.06.2024 11:45:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[sp_RestoreDBbyHistory] (
 @SourceDB  varchar(200),
 @DestinationDB varchar(200)   =NULL,
 @RestoreToTime datetime    =NULL,   --'yyyy-mm-dd hh:mi:ss', ie. '2012-04-27 22:19:20'
 @RecoveryMode varchar(10)    ='Recovery',  --'Recovery' or 'Norecovery'
 @ListMode   varchar(10)   ='OnlyValid'   --'All' or 'OnlyValid'
 )
AS
/*********************************************************************************************
Generate database restore script by backup history, it can
1. give out the restore script and sequence
 @ListMode='All' :   lists all possible restore scripts before @RestoreToTime
 @ListMode='OnlyValid' :  gives out a best valid restore way with mininum script.
2. check if the backup file existed

blog: http://jamessql.blogspot.com/
Example:
1. Generate restore script for database RS
EXEC sp_RestoreDBbyHistory @SourceDB='RS'
2. Generate all possible restore script for database RS, restore it as name 'RS_restored' to '2012-04-30 14:13:30.000' and with norecovery
[sp_RestoreDBbyHistory]
@SourceDB='RS'
,@DestinationDB='RS_restored'
,@RestoreToTime ='2012-04-30 14:13:30.000'
,@RecoveryMode ='Norecovery'
,@ListMode='All'
Pleaes test it by yourself first.
*********************************************************************************************/
BEGIN

 DECLARE @Exists int
 DECLARE @File_Exists varchar(30)
 DECLARE @backup_start_date datetime
 DECLARE @backup_finish_date datetime
 DECLARE @first_lsn numeric(25,0)
 DECLARE @last_lsn numeric(25,0)
 DECLARE @position int
 DECLARE @backup_type varchar(20)
 DECLARE @backup_size numeric(20,0)
 DECLARE @physical_device_name varchar(500)
 DECLARE @backupset_name varchar(500)
 DECLARE @differential_base_lsn numeric(25,0)
 DECLARE @database_backup_lsn numeric(25,0)

 DECLARE @restore_command varchar(max)
 DECLARE @lastfile bit
 DECLARE @stopat varchar(50)
 DECLARE @MOVETO VARCHAR(MAX)
 DECLARE @MOVETO_temp VARCHAR(MAX)
 DECLARE @first_backup_set_id int

 IF (@SourceDB is NULL)
 BEGIN
  PRINT 'Please input the @SourceDB name!'
  RETURN
 END

 IF (@DestinationDB is NULL)
  SET @DestinationDB=@SourceDB

 if (@RestoreToTime is NULL)
 BEGIN
  SET @stopat=''
  SET @RestoreToTime=GETDATE()
 END
 else
  SET @stopat=', STOPAT = '''+CONVERT(varchar(500), @RestoreToTime)+''''

 IF (@RecoveryMode NOT IN ('Recovery', 'Norecovery'))
 BEGIN
  PRINT 'Please set parameter @RecoveryMode with value ''Recovery'' or ''Norecovery'''
  RETURN
 END

 IF (@ListMode NOT IN ('All', 'OnlyValid'))
 BEGIN
  PRINT 'Please set parameter @@Mode with value ''All'' or ''OnlyValid'''
  RETURN
 END

 SET @lastfile=0
 SET @MOVETO=''

 --FIND the last valid full backup
 SELECT TOP 1 @first_backup_set_id=backup_set_id
 FROM MSDB..backupset bs
 WHERE bs.type='D'
 AND bs.backup_start_date<=@RestoreToTime
 AND bs.database_name=@SourceDB
 AND bs.user_name <> 'NT AUTHORITY\SYSTEM'
 ORDER BY bs.backup_start_date DESC



 IF (@first_backup_set_id IS NULL)
 BEGIN
  SELECT @first_backup_set_id=MIN(bs.backup_set_id)
  FROM MSDB..backupset bs
  WHERE bs.database_name=@SourceDB AND bs.backup_start_date<=@RestoreToTime  AND bs.user_name <> 'NT AUTHORITY\SYSTEM'
 
  IF (@first_backup_set_id IS NULL)
  BEGIN
   PRINT 'There is no any valid backup!!!'
   return
  END
  ELSE
   PRINT 'There is no valid full backup!!!'
  
 END
 ELSE
 BEGIN
  SELECT @MOVETO=@MOVETO+'MOVE N''' +bf.logical_name+''' TO N'''+
  REVERSE(RIGHT(REVERSE(bf.physical_name),(LEN(bf.physical_name)-
  CHARINDEX('\', REVERSE(bf.physical_name),1))+1))+
  CASE
   WHEN bf.file_number = 1 THEN @DestinationDB+'_data.mdf'
   WHEN (bf.file_number <> 1) and (bf.file_type = 'L') THEN @DestinationDB+'_log'+CONVERT(varchar(30),bf.file_number)+'.ldf'
   WHEN (bf.file_number <> 1) and (bf.file_type = 'D') THEN @DestinationDB+'_data'+CONVERT(varchar(30),bf.file_number)+'.ndf'
   ELSE @DestinationDB+'_'+CONVERT(varchar(30),bf.file_number)+'.ndf'
  END +
  ''','
  FROM msdb..backupfile bf LEFT JOIN msdb..backupset bs on bf.backup_set_id=bs.backup_set_id
  where bf.backup_set_id=@first_backup_set_id
  SET @MOVETO_temp=@MOVETO
 END

 CREATE TABLE #RestoreCommand(
  ID int NOT NULL IDENTITY (1, 1),
  backup_start_date datetime,
  backup_finish_date datetime,
  database_backup_lsn numeric(25,0),
  differential_base_lsn numeric(25,0),
  first_lsn numeric(25,0),
  last_lsn numeric(25,0),
  postion int,
  backup_type varchar(20),
  backup_size numeric(20,0),
  physical_device_name varchar(500) ,
  backupset_name varchar(500),
  restore_command varchar(max),
  fileExist varchar(20)
 )
 IF (@ListMode='All')
  SET @first_backup_set_id=1
 DECLARE backup_cursor CURSOR FOR
 SELECT
    bs.backup_start_date, 
    bs.backup_finish_date,
    bs.database_backup_lsn,
    bs.differential_base_lsn,
    bs.first_lsn,
    bs.last_lsn,
    position,
    CASE bs.type 
     WHEN 'D' THEN 'Full' 
     WHEN 'L' THEN 'Log' 
     WHEN 'I' THEN 'Diff'
    END AS backup_type, 
    bs.backup_size,
    bmf.physical_device_name,  
    bs.name AS backupset_name
 FROM   msdb.dbo.backupmediafamily  bmf
    INNER JOIN msdb.dbo.backupset bs ON bmf.media_set_id = bs.media_set_id 
 WHERE bs.database_name=@SourceDB
 AND bs.backup_set_id>=@first_backup_set_id
 AND bs.user_name <> 'NT AUTHORITY\SYSTEM'
 ORDER BY 
    bs.backup_start_date

 OPEN backup_cursor;
 FETCH NEXT FROM backup_cursor
 INTO @backup_start_date,@backup_finish_date,@database_backup_lsn,@differential_base_lsn,@first_lsn, @last_lsn,@position, @backup_type,@backup_size,@physical_device_name, @backupset_name

 WHILE ((@@FETCH_STATUS = 0) and (@lastfile <>1))
 BEGIN
  --check if file exist
  EXEC Master.dbo.xp_fileexist @physical_device_name, @Exists OUT
  IF  (@Exists= 1)
   SET @File_Exists= 'File Found'
  ELSE
   SET @File_Exists= 'File Not Found'
  
  IF (@backup_start_date<=@RestoreToTime)
  BEGIN
   --if this diff backup, then remove all log backup before it.
   IF ((@backup_type='Diff') and (@ListMode='OnlyValid'))
    DELETE FROM #RestoreCommand
    WHERE backup_type IN ('Log', 'Diff')
  
   IF @backup_type='Full'
   BEGIN
    SET @MOVETO_temp=@MOVETO
    IF (@ListMode='OnlyValid')
     DELETE FROM #RestoreCommand
   END
   ELSE
    SET @MOVETO_temp=''
   SET @restore_command=
    CASE  
     WHEN @backup_type in ('Full','Diff') THEN 'RESTORE DATABASE [' + @DestinationDB + '] FROM  DISK = N'''+ @physical_device_name +''' WITH  FILE = '+convert(varchar(30),@position)+','+@MOVETO_temp+'NORECOVERY, NOUNLOAD,  STATS = 10'
     WHEN @backup_type = 'Log' THEN 'RESTORE LOG [' + @DestinationDB + '] FROM  DISK = N'''+ @physical_device_name +''' WITH  FILE = '+convert(varchar(30),@position)+','+@MOVETO_temp+'NORECOVERY, NOUNLOAD, STATS = 10'
    END
  
   INSERT INTO #RestoreCommand (
    backup_start_date,
    backup_finish_date,
    database_backup_lsn ,
    differential_base_lsn,
    first_lsn,
    last_lsn,
    postion,
    backup_type,
    backup_size,
    physical_device_name ,
    backupset_name,
    restore_command,
    fileExist)
   VALUES
   (
    @backup_start_date,
    @backup_finish_date,
    @database_backup_lsn ,
    @differential_base_lsn,
    @first_lsn,
    @last_lsn,
    @position,
    @backup_type,
    @backup_size,
    @physical_device_name,
    @backupset_name,
    @restore_command,
    @File_Exists
   )
  END
  ELSE
   IF (@backup_type='Log')
   BEGIN
    SET @lastfile=1
    SET @restore_command='RESTORE LOG [' + @DestinationDB + '] FROM  DISK = N'''+ @physical_device_name +''' WITH  FILE = '+convert(varchar(30),@position)+',NORECOVERY, NOUNLOAD, STATS = 10'
    SET @restore_command=REPLACE(@restore_command, 'NORECOVERY','RECOVERY')+@stopat
    INSERT INTO #RestoreCommand (
     backup_start_date,
     backup_finish_date,
     database_backup_lsn ,
     differential_base_lsn,
     first_lsn,
     last_lsn,
     postion,
     backup_type,
     backup_size,
     physical_device_name ,
     backupset_name,
     restore_command,
     fileExist)
    VALUES
    (
     @backup_start_date,
     @backup_finish_date,
     @database_backup_lsn ,
     @differential_base_lsn,
     @first_lsn,
     @last_lsn,
     @position,
     @backup_type,
     @backup_size,
     @physical_device_name,
     @backupset_name,
     @restore_command,
     @File_Exists
    )
   END
  FETCH NEXT FROM backup_cursor
  INTO @backup_start_date,@backup_finish_date,@database_backup_lsn,@differential_base_lsn,@first_lsn, @last_lsn,@position, @backup_type,@backup_size,@physical_device_name, @backupset_name
 END
 CLOSE backup_cursor;
 DEALLOCATE backup_cursor;

 IF (@lastfile<>1)
  INSERT INTO #RestoreCommand (
   restore_command)
  VALUES
   (
   'You need to back up the Tail of the Log on database [' +@SourceDB+'] before restoring, then restore the tail-log backup with recovery as last step!'
   )

IF (SELECT TOP 1 1 from #RestoreCommand WHERE physical_device_name LIKE 'http%') = 1
       SELECT REPLACE(restore_command, 'DISK', 'URL') AS RestoreCommand, *  
	   from #RestoreCommand order by [ID]
ELSE 
        SELECT restore_command AS RestoreCommand, *  
	   from #RestoreCommand order by [ID]

END
GO


