USE [msdb]
GO

/****** Object:  Job [DBA: SQL Alert Status Check]    Script Date: 21.03.2024 14:08:28 ******/
EXEC msdb.dbo.sp_delete_job @job_name=N'DBA: SQL Alert Status Check', @delete_unused_schedule=1
GO

/****** Object:  Job [DBA: SQL Alert Status Check]    Script Date: 21.03.2024 14:08:28 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 21.03.2024 14:08:28 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Alert Status Check', 
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
/****** Object:  Step [Check If SQL Alert is enabled or disabled]    Script Date: 21.03.2024 14:08:29 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check If SQL Alert is enabled or disabled', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Check if Alert is created
IF (SELECT COUNT(*) FROM msdb..sysalerts  where enabled = 1) > (SELECT COUNT(*) FROM SQLAlertsBase  where enabled = 1)
BEGIN 

;WITH CreateAlert
AS
(
SELECT name, enabled
FROM msdb..sysalerts
EXCEPT
SELECT name,enabled
FROM SQLAlertsBase
)
SELECT *
INTO #CreateAlert
FROM CreateAlert

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@ServerName AS ''td'','''',  name AS ''td'','''', ''Alert '' + ''['' +name + '']'' +'' has been created'' AS ''td'',''''
FROM #CreateAlert
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Alert Status Change</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AlertName </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Alert Status Change''
EXEC UpdateSQLAlertsBase
END
GO

--Check if Alert is created
IF (SELECT COUNT(*) FROM msdb..sysalerts  where enabled = 1) < (SELECT COUNT(*) FROM SQLAlertsBase  where enabled = 1)
BEGIN 

;WITH DeletedAlert
AS
(
SELECT name, enabled
FROM SQLAlertsBase
EXCEPT
SELECT name,enabled
FROM msdb..sysalerts
)
SELECT *
INTO #DeletedAlert
FROM DeletedAlert

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@ServerName AS ''td'','''',  name AS ''td'','''', ''Alert '' + ''['' +name + '']'' +'' has been deleted'' AS ''td'',''''
FROM #DeletedAlert
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Alert Status Change</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AlertName </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Alert Status Change''
EXEC UpdateSQLAlertsBase
END
GO


--Send email if alert is disabled
IF (SELECT COUNT(enabled) FROM msdb..sysalerts  where enabled = 1) < (SELECT COUNT(enabled) FROM SQLAlertsBase  where enabled = 1)
BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@ServerName AS ''td'','''',  name AS ''td'','''', ''Alert '' + ''['' +name + '']'' +'' has been disabled'' AS ''td'',''''
FROM msdb..sysalerts where enabled = 0 
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Alert Status Change</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AlertName </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Alert Status Change''
EXEC UpdateSQLAlertsBase
END
GO

DROP TABLE IF EXISTS #EnabledAlerts
GO

--Find which alert is disabled
;WITH EnabledAlerts
AS
(
SELECT name, enabled
FROM SQLAlertsBase
EXCEPT
SELECT name,enabled
FROM msdb..sysalerts
)
SELECT *
INTO #EnabledAlerts
FROM EnabledAlerts
GO
--Send email if alert is enabled
IF (SELECT COUNT(enabled) FROM msdb..sysalerts  where enabled = 1) > (SELECT COUNT(enabled) FROM SQLAlertsBase  where enabled = 1)
BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@ServerName AS ''td'','''',  name AS ''td'','''', ''Alert '' + ''['' +name + '']'' +'' has been enabled'' AS ''td'',''''
FROM #EnabledAlerts 
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Alert Status Change</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AlertName </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Alert Status Change'';
EXEC UpdateSQLAlertsBase
END
GO', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240321, 
		@active_end_date=99991231, 
		@active_start_time=40000, 
		@active_end_time=235959, 
		@schedule_uid=N'45651a3b-028f-4663-b08b-ddf690aba80b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


