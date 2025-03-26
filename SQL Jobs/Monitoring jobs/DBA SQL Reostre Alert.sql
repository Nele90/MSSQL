USE [msdb]
GO

/****** Object:  Job [DBA: SQL Reostre Alert]    Script Date: 03.04.2024 16:23:08 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 03.04.2024 16:23:09 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Reostre Alert', 
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
/****** Object:  Step [Check restore for last hour]    Script Date: 03.04.2024 16:23:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check restore for last hour', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF EXISTS (SELECT 1 FROM    sys.fn_trace_gettable(CONVERT(VARCHAR(150), ( SELECT TOP 2
                                                              f.[value]
                                                      FROM    sys.fn_trace_getinfo(NULL) f
                                                      WHERE   f.property = 2
                                                    )), DEFAULT) T
        JOIN sys.trace_events TE ON T.EventClass = TE.trace_event_id
        JOIN sys.trace_subclass_values v ON v.trace_event_id = TE.trace_event_id
                                            AND v.subclass_value = t.EventSubClass
WHERE name = ''Audit Backup/Restore Event'' and StartTime > DATEADD(HOUR, -1, GETDATE()) and TextData NOT LIKE ''RESTORE FILELISTONLY%'' 
			and TextData NOT LIKE ''RESTORE HEADERONLY%'' and TextData NOT LIKE ''RESTORE LABELONLY%'' and TextData NOT LIKE ''RESTORE VERIFYONLY%'' and subclass_name = ''Restore'')

BEGIN
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)


SET @xml = CAST (( SELECT ServerName AS ''td'','''' ,CONVERT(nvarchar, StartTime, 21) AS ''td'','''',  HostName AS ''td'','''', ApplicationName AS ''td'','''',SessionLoginName AS ''td'','''',  DatabaseName AS ''td'','''', TextData AS ''td'','''', ''User '' + ''['' + SessionLoginName + '']'' +'' restored database: '' + DatabaseName AS ''td'',''''			
FROM    sys.fn_trace_gettable(CONVERT(VARCHAR(150), ( SELECT TOP 2
                                                              f.[value]
                                                      FROM    sys.fn_trace_getinfo(NULL) f
                                                      WHERE   f.property = 2
                                                    )), DEFAULT) T
        JOIN sys.trace_events TE ON T.EventClass = TE.trace_event_id
        JOIN sys.trace_subclass_values v ON v.trace_event_id = TE.trace_event_id
                                            AND v.subclass_value = t.EventSubClass
WHERE name = ''Audit Backup/Restore Event'' and StartTime > DATEADD(HOUR, -1, GETDATE()) and TextData NOT LIKE ''RESTORE FILELISTONLY%'' 
			and TextData NOT LIKE ''RESTORE HEADERONLY%'' and TextData NOT LIKE ''RESTORE LABELONLY%'' and TextData NOT LIKE ''RESTORE VERIFYONLY%'' and subclass_name = ''Restore''
ORDER BY StartTime
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Restore Database Alert</H3>
<table border = 1> 
<tr>
<th> ServerName </th> <th> StartTime </th> <th> LoginHostName </th> <th>  ApplicationName </th>  <th>  SessionLoginName </th> <th>  DatabaseName </th> <th>  Command </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''
EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address;;'',
@subject = ''SQL Restore Database Alert'';
END', 
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
		@active_start_date=20240402, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'70fdadc5-d85a-42ff-8d97-46fe29e77d65'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


