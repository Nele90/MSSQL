USE [msdb]
GO

/****** Object:  Job [DBA: SQL Object Usage History]    Script Date: 19.08.2024 10:23:32 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 19.08.2024 10:23:32 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Object Usage History', 
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
/****** Object:  Step [Collect_History_Data]    Script Date: 19.08.2024 10:23:33 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect_History_Data', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'INSERT INTO ObjectUsageByCPU  (
	[InsertDate],
	[DatabaseName],
	[DatabaseID],
	[ObjectID],
	[SchemaName],
	[ObjectType],
	[Objects],
	[Total_Execution_count],
	[Total_CPU_Time],
	[Avg_CPU_Time])
SELECT GETDATE () AS InsertDate,
    DB_NAME(st.dbid) AS DatabaseName,
	st.dbid as DatabaseID,
	st.objectid as ObjectID
    ,OBJECT_SCHEMA_NAME(st.objectid,dbid) AS SchemaName
    ,cp.objtype AS ObjectType
    ,OBJECT_NAME(st.objectid,dbid) AS Objects
    ,MAX(cp.usecounts)AS Total_Execution_count
    ,SUM(qs.total_worker_time) AS Total_CPU_Time
    ,SUM(qs.total_worker_time) / (max(cp.usecounts) * 1.0) AS Avg_CPU_Time 
FROM sys.dm_exec_cached_plans cp 
INNER JOIN sys.dm_exec_query_stats qs 
    ON cp.plan_handle = qs.plan_handle
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE DB_NAME(st.dbid) IS NOT NULL
GROUP BY DB_NAME(st.dbid),OBJECT_SCHEMA_NAME(objectid,st.dbid),cp.objtype,OBJECT_NAME(objectid,st.dbid),st.objectid,st.dbid', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete_Data_older_1_month]    Script Date: 19.08.2024 10:23:33 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete_Data_older_1_month', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DELETE FROM ObjectUsageByCPU
WHERE InsertDate < DATEADD(Month, -1, GETDATE())', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy at 5am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240819, 
		@active_end_date=99991231, 
		@active_start_time=50000, 
		@active_end_time=235959, 
		@schedule_uid=N'157bf368-4006-4bdd-8803-1713c07c1bb5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


