USE [msdb]
GO

/****** Object:  Job [DBA: SQL Object Usage]    Script Date: 17.03.2025 15:25:02 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 17.03.2025 15:25:02 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Object Usage', 
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
/****** Object:  Step [Check_Object_usage]    Script Date: 17.03.2025 15:25:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_Object_usage', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DROP TABLE  IF EXISTS #ObjectUsageReport
GO

;WITH base AS (
	SELECT 
		InstanceID,
		ObjectID,
		CAST(SUM(total_elapsed_time)/1000000.0 as decimal(8,2)) AS total_duration_sec,
		SUM(total_elapsed_time)/1000.0 / MAX(SUM(PeriodTime)/1000000.0) OVER() duration_ms_per_sec,
		SUM(total_elapsed_time/1000000.0)/SUM(execution_count) as avg_duration_sec,
		SUM(execution_count) as execution_count,
		SUM(execution_count) / MAX(SUM(PeriodTime)/60000000.0) OVER() execs_per_min,
		SUM(total_worker_time)/1000000.0 as total_cpu_sec,
		SUM(total_worker_time)/1000.0 / MAX(SUM(PeriodTime)/1000000.0) OVER() cpu_ms_per_sec,
		SUM(total_worker_time) /1000000.0 / SUM(execution_count) as avg_cpu_sec,
		SUM(total_physical_reads) as total_physical_reads,
		SUM(total_logical_reads) as total_logical_reads,
		SUM(total_logical_writes) as total_writes,
		SUM(total_logical_writes)/SUM(execution_count) as avg_writes,
		SUM(total_physical_reads)/SUM(execution_count) as avg_physical_reads,
		SUM(total_logical_reads)/SUM(execution_count) as avg_logical_reads,
		MAX(SUM(PeriodTime)/1000000.0) OVER() as period_time_sec,
		MAX(MaxExecutionsPerMin) as max_execs_per_min
	FROM dbo.ObjectExecutionStats 
	WHERE SnapshotDate>= DATEADD(Hour, -24, GETUTCDATE())
	GROUP BY InstanceID,ObjectID
	HAVING SUM(total_elapsed_time/1000000.0)/SUM(execution_count) > 10
	)
	SELECT 
		I.ConnectionID,
		D.name as DB,
		O.SchemaName,
		O.ObjectName,
		O.ObjectType,
		total_duration_sec,CAST(avg_duration_sec as decimal (8,2)) as avg_duration_sec,CAST(avg_cpu_sec as decimal(8,2)) as avg_cpu_sec,avg_writes,avg_physical_reads,avg_logical_reads,execution_count, execs_per_min
	INTO #ObjectUsageReport
	FROM base AS B
	JOIN dbo.Instances I ON B.InstanceID = I.InstanceID
	JOIN dbo.DBObjects O ON B.InstanceID = I.InstanceID AND B.ObjectID = O.ObjectID
	JOIN dbo.Databases D ON O.DatabaseID = D.DatabaseID AND D.InstanceID = I.InstanceID
	JOIN dbo.ObjectType OT ON OT.ObjectType = O.ObjectType
	WHERE D.name NOT IN (''DBA_DB'', ''msdb'', ''SSISDB'') and ObjectName <> ''ReceiveMessageToService''


DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)


SET @xml = CAST (( SELECT ConnectionID AS ''td'','''', DB AS ''td'','''',  SchemaName AS ''td'','''', ObjectName AS''td'','''',  ObjectType AS''td'','''',  total_duration_sec AS ''td'','''', avg_duration_sec AS ''td'','''', avg_cpu_sec AS ''td'','''',		
						  avg_writes AS ''td'','''',  avg_physical_reads AS ''td'','''',  avg_logical_reads AS ''td'','''',  execution_count AS ''td'','''',  execs_per_min AS ''td'',''''
FROM #ObjectUsageReport
ORDER BY avg_duration_sec DESC
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Object usage summary for last day</H3>
<table border = 1> 
<tr>
<th> ServerName </th> <th> DBName </th> <th> SchemaName </th> <th>  ObjectName </th>  <th>  ObjectType </th> <th>  total_duration_sec </th> <th>  avg_duration_sec </th> <th>  avg_cpu_sec </th> <th>  avg_writes </th> <th>  avg_physical_reads </th> <th>  avg_logical_reads </th> <th>  execution_count </th>  <th>  execs_per_min </th>''    


SET @body = @body + @xml +''</table></body></html>''
EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Object usage summary for last day'';


', 
		@database_name=N'DBADashDB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy at 7am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20250317, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959, 
		@schedule_uid=N'bd4a7bf7-e235-43ba-9d41-5ea8da4edb02'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


