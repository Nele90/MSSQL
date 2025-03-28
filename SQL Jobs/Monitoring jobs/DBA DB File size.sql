USE [msdb]
GO

/****** Object:  Job [DBA: Cvinet_file_size]    Script Date: 11.05.2023 08:56:12 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 11.05.2023 08:56:12 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'', 
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
/****** Object:  Step [check_file_size]    Script Date: 11.05.2023 08:56:12 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check_file_size', 
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

SET @role = (	select top 1 role_desc 
		from 
		sys.dm_hadr_availability_replica_cluster_states rcs
		INNER JOIN sys.dm_hadr_availability_replica_states ars ON rcs.replica_id = ars.replica_id
		WHERE replica_server_name = @@SERVERNAME
	     )

 SET @availability_mode = (	
 
 SELECT top 1 availability_mode FROM sys.availability_replicas WHERE replica_server_name = @@SERVERNAME
	    )

IF @role = ''PRIMARY''
BEGIN

SELECT [File Name] = name,
[File Location] = physical_name,
[Total Size (MB)] = size/128.0,
size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0 as [Available Free Space (MB)],
[Type] = type_desc
INTO #cvinet_file_size
FROM sys.database_files


IF EXISTS (SELECT 1 FROM #cvinet_file_size WHERE [Available Free Space (MB)] < 1000) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT [File Name] AS ''td'','''', [File Location] AS ''td'','''', [Available Free Space (MB)] AS ''td'','''' , [Total Size (MB)] AS ''td'',''''				
From #cvinet_file_size
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>Database Tlog status</H3>
<table border = 1> 
<tr>
<th> [File Name] </th> <th> [File Location] </th> <th> [Available Free Space (MB)] </th> <th> [Total Size (MB)] </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''Database Tlog status'';
END

ELSE 
BEGIN
-- Drop the temporary table  
DROP TABLE #cvinet_file_size
END
END
ELSE
BEGIN
	PRINT ''This is secondary and sync commit''
END
', 
		@database_name=N'cvinet', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230511, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'9d57a4cc-8c16-43a2-8fde-a10d76c9eed4'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
