USE [msdb]
GO

/****** Object:  Job [DBA: SQL Rights Change Check]    Script Date: 09.04.2024 08:22:57 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 09.04.2024 08:22:58 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Rights Change Check', 
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
/****** Object:  Step [Check if rights are change within last hour]    Script Date: 09.04.2024 08:22:59 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if rights are change within last hour', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Check if there is any permission change within last hour!
IF EXISTS(SELECT  1 FROM    sys.fn_trace_gettable(CONVERT(VARCHAR(150), ( SELECT TOP 1
                                                              f.[value]
                                                      FROM    sys.fn_trace_getinfo(NULL) f
                                                      WHERE   f.property = 2
                                                    )), DEFAULT) T
        JOIN sys.trace_events TE ON T.EventClass = TE.trace_event_id
        JOIN sys.trace_subclass_values v ON v.trace_event_id = TE.trace_event_id
                                            AND v.subclass_value = t.EventSubClass
WHERE name IN ( ''Audit Add Role Event'',
''Audit Add Member to DB Role Event'',
''Audit Add Login to Server Role Event'',
''Audit Login Change Property Event'',
--''Audit Login GDR Event'',
--''Audit Addlogin Event'',
''Audit Schema Object GDR Event'',
''Audit Database Scope GDR Event'',
''Audit Add DB User Event'')
AND StartTime > DATEADD(HOUR, -1, GETDATE()))
--send an email if enabled
--Send email 
BEGIN
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)
SET @xml = CAST ((SELECT name AS ''td'','''', CONVERT(varchar,StartTime,21) AS ''td'','''', ServerName AS ''td'','''',SessionLoginName AS ''td'','''',ApplicationName AS ''td'','''', HostName AS ''td'','''', DatabaseName  AS ''td'','''',
	CASE
			WHEN RoleName IS NULL and ObjectName IS NULL and subclass_name = ''Revoke database access'' THEN ''User has been dropped from db''
			WHEN RoleName IS NULL and ObjectName IS NULL and subclass_name = ''Grant database access'' THEN ''User has been grated public access to db''
			WHEN RoleName IS NULL THEN ''Role rights are not changed''
			ELSE RoleName
			END AS ''td'','''',
			
	CASE 
			WHEN RoleName = ObjectName THEN ''Role rights have been changed''
			WHEN ObjectName IS NULL and RoleName IS NULL and subclass_name = ''Revoke database access'' THEN ''User has been dropped from db''
			WHEN ObjectName IS NULL and RoleName IS NULL and subclass_name = ''Grant database access'' THEN ''User has been grated public access to db''
			WHEN RoleName IS NULL THEN ''Object rights are not changed''
			ELSE ObjectName
			END AS ''td'','''', 
	CASE	
			WHEN TargetUserName IS NULL AND subclass_name = ''Add'' THEN TargetLoginName 
			WHEN TargetUserName IS NULL AND subclass_name = ''Drop'' THEN TargetLoginName
			WHEN TargetUserName IS NULL AND subclass_name = ''Grant'' THEN TargetLoginName 
			WHEN TargetUserName IS NULL AND subclass_name = ''Default database changed'' THEN TargetLoginName 
			WHEN TargetUserName IS NULL AND subclass_name = ''Default language changed'' THEN TargetLoginName 
			WHEN TargetUserName IS NULL AND subclass_name = ''Policy changed'' THEN TargetLoginName 
			WHEN TargetUserName IS NULL AND subclass_name = ''Expiration changed'' THEN TargetLoginName 
			ELSE TargetUserName
			END AS ''td'','''', 
	CASE	WHEN TargetLoginName IS NULL AND subclass_name = ''Revoke database access'' THEN TargetUserName 
			WHEN TargetLoginName IS NULL AND subclass_name = ''Grant'' THEN TargetUserName 
			ELSE TargetLoginName
			END AS ''td'','''', 
	CASE
			WHEN TextData IS NULL and subclass_name = ''Revoke database access'' THEN ''USE '' + ''['' +DatabaseName + '']'' + '' DROP USER '' + ''['' + TargetLoginName + '']'' 
			WHEN TextData IS NULL and subclass_name = ''Grant database access'' THEN ''USE '' + ''['' +DatabaseName + '']'' + '' CREATE USER '' + ''['' + TargetLoginName + '']'' + '' FOR LOGIN ''  + ''['' + TargetLoginName + '']''
			WHEN TextData IS NULL and ApplicationName = ''dbatools PowerShell module - dbatools.io'' THEN ''Command for is not available for this change!''
			ELSE TextData
			END AS ''td'',''''
FROM    sys.fn_trace_gettable(CONVERT(VARCHAR(150), ( SELECT TOP 1
                                                              f.[value]
                                                      FROM    sys.fn_trace_getinfo(NULL) f
                                                      WHERE   f.property = 2
                                                    )), DEFAULT) T
        JOIN sys.trace_events TE ON T.EventClass = TE.trace_event_id
        JOIN sys.trace_subclass_values v ON v.trace_event_id = TE.trace_event_id
                                            AND v.subclass_value = t.EventSubClass
WHERE name IN ( ''Audit Add Role Event'',
''Audit Add Member to DB Role Event'',
''Audit Add Login to Server Role Event'',
''Audit Login Change Property Event'',
--''Audit Login GDR Event'',
--''Audit Addlogin Event'',
''Audit Schema Object GDR Event'',
''Audit Database Scope GDR Event'',
''Audit Add DB User Event'')
AND StartTime > DATEADD(HOUR, -1, GETDATE())
ORDER BY StartTime DESC
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Rights Change</H3>
<table border = 1> 
<tr>
<th> EventName </th> <th> StartTime </th> <th> ServerName </th> <th> SessionLoginName </th> <th> ApplicationName </th> <th> HostName </th> <th> DatabaseName </th> <th> RoleName </th> <th> ObjectName </th> <th> TargetUserName </th> <th> TargetLoginName </th> <th> Command </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address;'',
@subject = ''SQL Rights Change''
END', 
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
		@active_start_date=20240320, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'ce47a884-fc73-48e8-a4d3-47e8594176e7'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


