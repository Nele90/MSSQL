USE [msdb]
GO
/****** Object:  Job [DBA: SQL Memory Persure Check]    Script Date: 06.05.2024 10:07:27 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 06.05.2024 10:07:28 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Memory Persure Check', 
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
/****** Object:  Step [check memory presure]    Script Date: 06.05.2024 10:07:28 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check memory presure', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Check dm_os_sys_memory for low memory state
IF EXISTS (SELECT 1 FROM sys.dm_os_sys_memory WHERE system_low_memory_signal_state = 1 and system_memory_state_desc <> ''Physical memory state is transitioning'')
BEGIN
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@SERVERNAME AS ''td'','''', total_physical_memory_kb/1024 AS ''td'','''', available_physical_memory_kb/1024 AS ''td'','''', system_memory_state_desc AS ''td'',''''	
FROM sys.dm_os_sys_memory
WHERE system_low_memory_signal_state = 1
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Memory Presure Check</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> Total Physical Memory in MB </th> <th>  Physical Memory Available in MB </th> <th> System Memory State </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Memory Presure Check'';
END
GO
IF EXISTS (SELECT 1 FROM sys.dm_os_process_memory WHERE process_virtual_memory_low > 1 or process_physical_memory_low > 1)
BEGIN
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@SERVERNAME AS ''td'','''', physical_memory_in_use_kb/1024 AS ''td'','''', process_physical_memory_low AS ''td'','''', process_virtual_memory_low  AS ''td'','''',	
					CASE
						WHEN process_physical_memory_low > 1 THEN ''Physical Memory Low Indicates that the process is responding to low physical memory notification''
						WHEN process_virtual_memory_low > 1 THEN ''Virtual Memory Low Indicates that the process is responding to low physical memory notification''
						ELSE ''No memory presure''
					END AS ''td'',''''
FROM sys.dm_os_process_memory 
WHERE process_virtual_memory_low > 1 or process_physical_memory_low > 1
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Memory Presure Check</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> Physical Memory Used in MB </th> <th>  Physical Memory Low </th> <th>  Virtual Memory Low </th>  <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Memory Presure Check''
END
GO', 
		@database_name=N'master', 
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
		@active_start_date=20240322, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'4c902993-a75e-4069-b416-2f6d2cb69e3b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


