USE [msdb]
GO

/****** Object:  Job [DBA: SQL Password Expiration Policy Check]    Script Date: 23.02.2024 15:32:33 ******/
EXEC msdb.dbo.sp_delete_job @job_name=N'DBA: SQL Password Expiration Policy Check', @delete_unused_schedule=1
GO

/****** Object:  Job [DBA: SQL Password Expiration Policy Check]    Script Date: 23.02.2024 15:32:33 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 23.02.2024 15:32:34 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Password Expiration Policy Check', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [check for expiration policy]    Script Date: 23.02.2024 15:32:35 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check for expiration policy', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF EXISTS (SELECT 1 FROM GetLoginInfo WHERE is_expiration_checked = 1 and IsMustChange = 0) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT name AS ''td'','''',  TypeOfLogin AS ''td'','''', is_expiration_checked AS ''td'','''', IsMustChange AS ''td'','''', ''User '' + name + '' has expiration password policy enabled check why!!'' AS ''td'',''''			
FROM GetLoginInfo
WHERE is_expiration_checked = 1 and IsMustChange = 0
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Password Expiration Policy Check</H3>
<table border = 1> 
<tr>
<th> name </th> <th> TypeOfLogin </th> <th>  is_expiration_checked </th> <th>  IsMustChange </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Password Expiration Policy Check'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''There is no user with enabled passowrd expiration policy''
END
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240223, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'0fcd4582-a3dc-4767-9b37-bbb1851988af'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


