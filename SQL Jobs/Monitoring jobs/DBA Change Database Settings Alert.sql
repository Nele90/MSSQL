USE [msdb]
GO

/****** Object:  Job [DBA: Change Database Settings Alert]    Script Date: 05.04.2024 09:06:26 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 05.04.2024 09:06:26 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Change Database Settings Alert', 
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
/****** Object:  Step [Check if db settings has been changed in last one hour]    Script Date: 05.04.2024 09:06:27 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if db settings has been changed in last one hour', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Time_Start DATETIME;
DECLARE @Time_End DATETIME;
SET @Time_Start =dateadd(hour, -1,getdate());
SET @Time_End = getdate();
-- Create the temporary table
CREATE TABLE #ErrorLog (
	logdate DATETIME
	,processinfo VARCHAR(MAX)
	,Message VARCHAR(MAX)
	)
-- Populate the temporary tablesys
INSERT #ErrorLog (
	logdate
	,processinfo
	,Message
	)
EXEC master.dbo.xp_readerrorlog 0
	,1
	,NULL
	,NULL
	,@Time_Start
	,@Time_End
	,N''desc'';
-- Filter the temporary table
IF EXISTS (SELECT 1 FROM #ErrorLog WHERE Message LIKE ''Setting database option %'')
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@SERVERNAME AS ''td'','''', CONVERT(datetime, logdate, 21)  AS ''td'','''',  Message AS ''td'','''', ''Database setting has been changed check who and why changed it!!'' AS ''td'',''''			
FROM #ErrorLog
WHERE Message LIKE ''Setting database option %''
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Database Setting Change</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> Logdatetime </th> <th>  Message </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Database Setting Change'';
END

DROP TABLE IF EXISTS #ErrorLog', 
		@database_name=N'master', 
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
		@active_start_date=20240405, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'd40334da-7c92-4191-8077-04d3cb215c67'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


