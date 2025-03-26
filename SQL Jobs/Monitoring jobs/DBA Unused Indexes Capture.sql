USE [msdb]
GO

/****** Object:  Job [DBA: Unused Indexes Capture]    Script Date: 15.05.2024 12:55:37 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 15.05.2024 12:55:38 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Unused Indexes Capture', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Capture_unused_indexes]    Script Date: 15.05.2024 12:55:39 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Capture_unused_indexes', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB
DROP TABLE IF EXISTS [#UnusedIndexes] 
GO

CREATE TABLE [dbo].[#UnusedIndexes](
	[InsertDate] [datetime] NOT NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [sysname] NOT NULL,
	[TableName] [sysname] NOT NULL,
	[IndexName] [sysname] NULL,
	[IndexUpdates] [bigint] NOT NULL,
	[UserLookups] [bigint] NOT NULL,
	[UserSeeks] [bigint] NOT NULL,
	[UserScans] [bigint] NOT NULL
) ON [PRIMARY]
GO

EXEC sp_MSforeachdb ''
USE [?]
IF DB_ID() > 4
INSERT INTO #UnusedIndexes
SELECT
GETDATE() as InsertDate,
DB_NAME() AS DatabaseName,
s.name AS SchemaName,
o.name AS TableName,
i.name AS IndexName,
iu.user_updates as IndexUpdates,
iu.user_lookups as UserLookups,
iu.user_seeks AS UserSeeks,
iu.user_scans as UserScans
FROM sys.dm_db_index_usage_stats iu
INNER JOIN sys.objects o
ON iu.object_id = o.object_id
INNER JOIN sys.schemas s
ON o.schema_id = s.schema_id
INNER JOIN sys.indexes i
ON o.object_id = i.object_id
AND i.index_id = iu.index_id
WHERE iu.database_id = DB_ID()
AND i.is_primary_key = 0
AND i.is_unique = 0
AND iu.user_lookups = 0
AND iu.user_scans = 0
AND iu.user_seeks = 0''
GO

INSERT INTO UnusedIndexes (InsertDate,DatabaseName,SchemaName,TableName,IndexName,IndexUpdates,UserLookups,UserSeeks,UserScans)
SELECT * 
FROM #UnusedIndexes;




', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy at 1am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240514, 
		@active_end_date=99991231, 
		@active_start_time=10000, 
		@active_end_time=235959, 
		@schedule_uid=N'82dc68dd-41c6-4795-8e1f-379f766cd40a'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


