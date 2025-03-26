/****** Object:  Job [DBA: SQL Extended Event Check]    Script Date: 07.03.2024 12:38:29 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 07.03.2024 12:38:30 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Extended Event Check', 
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
/****** Object:  Step [Check_extended_event]    Script Date: 07.03.2024 12:38:30 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_extended_event', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF (Select COUNT(name) from SQLExtendedEventBase WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1'')) < (SELECT COUNT(name) from sys.server_event_sessions WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1''))
BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT name AS ''td'','''',  startup_state AS ''td'','''' ,  ''New Extended Event '' + ''['' +name + '']'' + '' has been created '' AS ''td'','''' 
FROM sys.server_event_sessions
WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1'')
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Extended Event Creation</H3>
<table border = 1> 
<tr>
<th> NewEventName </th> <th> startup_state </th>  <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Extended Event Creation'';

--update base table, drop and add new value
DROP TABLE SQLExtendedEventBase

select name,startup_state
INTO SQLExtendedEventBase
from sys.server_event_sessions
WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1'')
END
GO



IF (Select COUNT(name) from SQLExtendedEventBase WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1'')) > (SELECT COUNT(name) from sys.server_event_sessions WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1''))
BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT name AS ''td'','''',  startup_state AS ''td'','''' ,  ''Extended Event '' + ''['' +name + '']'' + '' has been deleted'' AS ''td'','''' 
FROM SQLExtendedEventBase
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Extended Event Deletion</H3>
<table border = 1> 
<tr>
<th> NewEventName </th> <th> startup_state </th>  <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Extended Event Deletion'';

--update base table, drop and add new value
DROP TABLE SQLExtendedEventBase

select name,startup_state
INTO SQLExtendedEventBase
from sys.server_event_sessions
WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1'')
END
GO


--DROP TABLE SQLExtendedEventBase

--select name,startup_state
--INTO SQLExtendedEventBase
--from sys.server_event_sessions
--WHERE Name not IN (''system_health'',''AlwaysOn_health'',''QuickSessionTSQL'',''QuickSessionStandard'',''telemetry_xevents'',''DBADash_1'')
', 
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
		@active_start_date=20240307, 
		@active_end_date=99991231, 
		@active_start_time=50000, 
		@active_end_time=235959, 
		@schedule_uid=N'd4b9635b-0796-431d-bcd5-de084e5626bf'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


