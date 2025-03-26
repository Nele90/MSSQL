USE [msdb]
GO

/****** Object:  Job [DBA: SQL Backup History Into Table]    Script Date: 02.07.2024 08:18:35 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Maintenance]    Script Date: 02.07.2024 08:18:36 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Backup History Into Table', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'SQL DBA Maintenance', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Insert backup history into table]    Script Date: 02.07.2024 08:18:36 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert backup history into table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB
INSERT INTO [dbo].[BackupTbl_Backup_History]
           ([database_name]
           ,[backup_start_date]
           ,[backup_finish_date]
           ,[backup_type]
           ,[DurationTime HH:MM]
           ,[server_name]
           ,[software_name]
           ,[Who Perform backup]
           ,[expiration_date]
           ,[BackupName]
           ,[BackupDescription]
           ,[BackupSize in MB]
           ,[physical_device_name]
           ,[first_lsn]
           ,[last_lsn]
           ,[checkpoint_lsn]
           ,[recovery_model]
           ,[database_backup_lsn]
           ,[is_damaged]
           ,[has_incomplete_metadata]
           ,[Number of Backed Up Files]
           ,[Number of Backed Up Filegroups])
SELECT  bs.database_name
  , bs.backup_start_date
  , bs.backup_finish_date
  , CASE bs.type
 WHEN ''D'' THEN ''FullBackup'' 
 WHEN ''I'' THEN ''DifferentialBackup'' 
 WHEN ''L'' THEN ''LogBackup'' 
 WHEN ''F'' THEN ''FileBackup''
 WHEN ''G'' THEN ''DifferentialFileBackup''
 WHEN ''P'' THEN ''PartialBackup''
 WHEN ''Q'' THEN ''DifferentialPartialBackup'' 
 ELSE NULL  
  END AS ''backup_type''
  , CAST(DATEDIFF(minute,bs.backup_start_date,bs.backup_finish_date)/60 AS NVARCHAR(10))
  + '':''
  + CAST(DATEDIFF(minute,bs.backup_start_date,bs.backup_finish_date)%60 AS NVARCHAR(10))
  AS ''DurationTime HH:MM''
--  , bs.backup_set_id
  , bs.server_name
  , bms.software_name
  , bs.user_name AS ''Who Perform backup''
  --, bs.media_set_id
  , bs.expiration_date
  , bs.name AS ''BackupName''
  , bs.description AS ''BackupDescription''
  , CAST(bs.backup_size/1048576 AS NUMERIC(10,2)) AS ''BackupSize in MB''
  , bmf.physical_device_name
  , bs.first_lsn
  , bs.last_lsn
  , bs.checkpoint_lsn
  , bs.recovery_model
  , bs.database_backup_lsn
  , bs.is_damaged
  , bs.has_incomplete_metadata
 , bf.[Number of Backed Up Files]
, bfg.[Number of Backed Up Filegroups]
--  , bf.physical_drive
--  , bf.logical_name
--  , bf.physical_name 
--  , bf.state_desc AS ''BackupFileDescription''
--  , bf.file_type
--INTO BackupTbl_Backup_History
FROM msdb..backupset bs 
LEFT OUTER JOIN 
(SELECT backup_set_id, SUM(backup_size) AS ''SumBackupSize'', COUNT(*) AS ''Number of Backed Up Files''
FROM msdb..backupfile
WHERE backup_size > 0
GROUP BY backup_set_id) bf 
 ON bs.backup_set_id = bf.backup_set_id 
LEFT OUTER JOIN msdb..backupmediafamily bmf 
 ON bmf.media_set_id = bs.media_set_id
LEFT OUTER JOIN msdb..backupmediaset bms 
 ON bms.media_set_id = bs.media_set_id
LEFT OUTER JOIN 
(SELECT backup_set_id, COUNT(*) AS ''Number of Backed Up Filegroups''
FROM msdb..backupfilegroup
GROUP BY backup_set_id) bfg 
 ON bfg.backup_set_id = bs.backup_set_id
WHERE bs.backup_finish_date > DATEADD(Hour, -24, GETDATE())
ORDER BY bs.backup_finish_date DESC, bs.database_name', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete data older than 2 months]    Script Date: 02.07.2024 08:18:36 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete data older than 2 months', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DELETE FROM BackupTbl_Backup_History
WHERE backup_finish_date < DATEADD(Month, -2, GETDATE())', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy at 4am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240702, 
		@active_end_date=99991231, 
		@active_start_time=40000, 
		@active_end_time=235959, 
		@schedule_uid=N'70fe99f9-fe27-418e-b1b4-c7c7777304e8'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


