USE [msdb]
GO

/****** Object:  Job [DBA: Error log check]    Script Date: 15.11.2023 09:13:53 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 15.11.2023 09:13:53 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Error log check', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'owner name', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check error log]    Script Date: 15.11.2023 09:13:54 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check error log', 
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
SET @Time_Start = DATEADD(HOUR, -1, GETDATE());
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

IF EXISTS (SELECT 1 FROM #ErrorLog WHERE (
  Message LIKE ''%error%''
  OR Message LIKE ''%failed%''
  )
 AND processinfo NOT LIKE ''logon''
 AND (Message NOT LIKE ''DBCC CHECKDB%found 0 errors%'')
 AND (Message NOT LIKE ''CHECKDB for database%finished without errors%'')
 AND (Message NOT LIKE ''The error log has been reinitialized.%'')
 AND (Message NOT LIKE ''Logging SQL Server messages in file%'')
 AND (Message NOT LIKE ''The client was unable to reuse a session with SPID%'')
 AND (Message NOT LIKE ''Error: 18056, Severity: 20, State%'')
 AND (Message NOT LIKE ''Error: 18054, Severity: 16, State%'')
 AND (Message NOT LIKE ''Error 777980050, severity 16, state 1 was raised, but no message with that error number was found%'')
 AND (Message NOT LIKE ''DbMgrPartnerCommitPolicy%'')
 AND (Message NOT LIKE ''Always On Availability Groups connection with%'')
 AND (Message NOT LIKE ''DbMgrPartnerCommitPolicy::SetSyncAndRecoveryPoint%'')
 AND (Message NOT LIKE ''Error 777980008, severity 16%'')
 AND (Message NOT LIKE ''Error: 9642, Severity: 16, State: 3%'')
 AND (Message NOT LIKE ''An error occurred in a Service Broker/Database Mirroring transport connection endpoint%'')
) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)
DECLARE @Subj NVARCHAR(MAX)
SET @Subj = ''Error Log on '' + @@SERVERNAME


SET @xml = CAST (( SELECT CONVERT(varchar,LogDate,21) AS ''td'','''', Message AS ''td'',''''
     
From #ErrorLog
WHERE (
  Message LIKE ''%error%''
  OR Message LIKE ''%failed%''
  )
 AND processinfo NOT LIKE ''logon''
 AND (Message NOT LIKE ''DBCC CHECKDB%found 0 errors%'')
 AND (Message NOT LIKE ''CHECKDB for database%finished without errors%'')
 AND (Message NOT LIKE ''The error log has been reinitialized.%'')
 AND (Message NOT LIKE ''Logging SQL Server messages in file%'')
 AND (Message NOT LIKE ''The client was unable to reuse a session with SPID%'')
 AND (Message NOT LIKE ''Error: 18056, Severity: 20, State%'')
 AND (Message NOT LIKE ''Error: 18054, Severity: 16, State%'')
 AND (Message NOT LIKE ''Error 777980050, severity 16, state 1 was raised, but no message with that error number was found%'')
 AND (Message NOT LIKE ''DbMgrPartnerCommitPolicy%'')
 AND (Message NOT LIKE ''Always On Availability Groups connection with%'')
 AND (Message NOT LIKE ''DbMgrPartnerCommitPolicy::SetSyncAndRecoveryPoint%'')
 AND (Message NOT LIKE ''Error 777980008, severity 16%'')
 AND (Message NOT LIKE ''Error: 9642, Severity: 16, State: 3%'')
 AND (Message NOT LIKE ''An error occurred in a Service Broker/Database Mirroring transport connection endpoint%'')
ORDER BY logdate DESC

FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>Error log check</H3>
<table border = 1> 
<tr>
<th> LogDate </th> <th> Message </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = @Subj;
END

ELSE 
BEGIN
-- Drop the temporary table  
DROP TABLE #ErrorLog
END

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every hour', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230309, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959, 
		@schedule_uid=N'8114cf84-f380-4a6e-a2b8-256e98756f93'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


