USE [msdb]
GO

/****** Object:  Job [DBA: Check_LongRuning_Locks]    Script Date: 2/2/2024 11:31:02 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 2/2/2024 11:31:02 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Check_LongRuning_Locks', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'owner name', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check_Long_Running_Locks]    Script Date: 2/2/2024 11:31:02 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_Long_Running_Locks', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @role VARCHAR(10)
DECLARE @availability_mode int

SET @role = (	select role_desc 
		from 
		sys.dm_hadr_availability_replica_cluster_states rcs
		INNER JOIN sys.dm_hadr_availability_replica_states ars ON rcs.replica_id = ars.replica_id
		WHERE replica_server_name = @@SERVERNAME
	     )

 SET @availability_mode = (	
 
 SELECT availability_mode FROM sys.availability_replicas WHERE replica_server_name = @@SERVERNAME
	    )

IF @role = ''PRIMARY''
BEGIN
	
--execute sp to collect data 
exec sp_WhoIsActive @destination_table=''WhoisActive''

--send an email if there is long running lock >5 min
IF EXISTS (SELECT 1 FROM WhoisActive WHERE blocking_session_id IS NOT NULL and [dd hh:mm:ss.mss] > ''00 00:05:00.000'') 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT CONVERT(varchar, [collection_time], 120) AS ''td'','''', [dd hh:mm:ss.mss] AS ''td'','''', [wait_info] AS ''td'','''', [blocking_session_id] AS ''td'','''', 
[host_name] AS ''td'','''', [database_name] AS ''td'','''', [program_name] AS ''td'','''', [start_time] AS ''td'',''''					
 From WhoisActive
WHERE blocking_session_id IS NOT NULL and [dd hh:mm:ss.mss] > ''00 00:05:00.000''
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>Long running Lock</H3>
<table border = 1> 
<tr>
<th> collection_time </th> <th> DurationOfLock </th> <th> wait_info </th> <th> blocking_session_id </th> <th> host_name </th> <th> database_name </th> <th> program_name </th> <th> start_time </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address; '',
@subject = ''Long running Lock'';
END

--clean up table
DELETE FROM WhoisActive Where collection_time < DATEADD(HOUR, -1, GETDATE())

END
ELSE
BEGIN
	PRINT ''This is secondary node'';
END
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every 5 min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240105, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'90f63424-d481-4e6a-bd27-ec1d95df984b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


