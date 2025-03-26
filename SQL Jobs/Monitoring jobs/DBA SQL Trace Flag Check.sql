USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Trace Flag Check', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: SQL Trace Flag Check'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: SQL Trace Flag Check', @step_name=N'check_trace_flags', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Create and fill the temp table
CREATE TABLE #SQLTraceFlagTemp(
        TraceFlag NVARCHAR(40)
,       Status TINYINT
,       GLOBAL TINYINT
,       SESSION TINYINT
)
GO
INSERT INTO #SQLTraceFlagTemp 
	EXEC(''dbcc tracestatus'')
GO

--Check for disabled tf
;WITH
DisabledTF
AS
(
	SElect *
	from SQLTraceFlagBase
	EXCEPT
		SElect *
	from #SQLTraceFlagTemp
)
SELECT * 
INTO #DisabledTF
FROM DisabledTF
GO
--send an email if disabled
if EXISTS ( select 1 from #DisabledTF)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT TraceFlag AS ''td'','''', ''New Trace Flag '' + ''['' + TraceFlag + '']'' +'' has been disabled!!!'' AS ''td'',''''			
FROM #DisabledTF
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Trace Flag Disabled</H3>
<table border = 1> 
<tr>
<th> TraceFlagName </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Trace Flag Disabled'';
EXEC UpdateSQLTraceFlagBase
END
GO


--Check for enabled tf
;WITH
EnabledTF
AS
(
	SElect *
	from #SQLTraceFlagTemp
	EXCEPT
	SElect *
	from SQLTraceFlagBase
	
)
SELECT * 
INTO #EnabledTF
FROM EnabledTF
GO

--send an email if enabled
if EXISTS ( select 1 from #EnabledTF)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT TraceFlag AS ''td'','''', ''New Trace Flag '' + ''['' + TraceFlag + '']'' +'' has been enabled!!!'' AS ''td'',''''			
FROM #EnabledTF
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Trace Flag Enabled</H3>
<table border = 1> 
<tr>
<th> TraceFlagName </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Trace Flag Enabled'';
exec UpdateSQLTraceFlagBase
END
GO


DROP TABLE #SQLTraceFlagTemp
DROP TABLE  #DisabledTF
DROP TABLE  #EnabledTF
GO', 
		@database_name=N'DBA_DB', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA: SQL Trace Flag Check', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: SQL Trace Flag Check', @name=N'Dailiy', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240311, 
		@active_end_date=99991231, 
		@active_start_time=40000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
