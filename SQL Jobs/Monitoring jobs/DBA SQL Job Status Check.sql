/****** Object:  Job [DBA: SQL Job Status Check]    Script Date: 08.03.2024 09:48:00 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 08.03.2024 09:48:00 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Job Status Check', 
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
/****** Object:  Step [Check_if_job_created]    Script Date: 08.03.2024 09:48:01 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_if_job_created', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'if EXISTS ( select 1 from SQLJobsBase)
BEGIN
PRINT ''SQLJobBase is updated''
END
ELSE
BEGIn
insert INTO SQLJobsBase(name,enabled)
SELECT name, enabled 
from msdb..sysjobs 
END

IF (select count(name) from msdb..sysjobs) > (SELECT count(name) FROM SQLJobsBase)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT name AS ''td'','''', ''New job '' + ''['' +name + '']'' +'' has been created!!!'' AS ''td'',''''			
FROM msdb..sysjobs 
WHERE date_created > DATEADD(Hour, -1, getdate())
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Agent Job Creation</H3>
<table border = 1> 
<tr>
<th> NewJobName </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Agent Job Creation'';
EXEC UpdateSQLJobsBase
END
GO
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [check_if_job_deleted]    Script Date: 08.03.2024 09:48:01 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check_if_job_deleted', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'if EXISTS ( select 1 from SQLJobsBase)
BEGIN
PRINT ''SQLJobBase is updated''
END
ELSE
BEGIn
insert INTO SQLJobsBase(name,enabled)
SELECT name, enabled 
from msdb..sysjobs 
END

IF (select count(name) from msdb..sysjobs) < (SELECT count(name) FROM SQLJobsBase)
 BEGIN 
WITH DeleteTable
AS
(
select name
from SQLJobsBase
except
select name
from msdb..sysjobs 
)

SELECT name
INTO #DelteTable
FROM DeleteTable

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT name AS ''td'','''', ''Job '' + ''['' + name + '']'' +  '' has been deleted!!!'' AS ''td'',''''			
FROM #DelteTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Agent Job Deletion</H3>
<table border = 1> 
<tr>
<th> name </th> <th> comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Agent Job Deletion'';
DROP TABLE #DelteTable
EXEC UpdateSQLJobsBase
END
GO', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check_if_job_disabled]    Script Date: 08.03.2024 09:48:01 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_if_job_disabled', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'if EXISTS ( select 1 from SQLJobsBase)
BEGIN
PRINT ''SQLJobBase is updated''
END
ELSE
BEGIn
insert INTO SQLJobsBase(name,enabled)
SELECT name, enabled 
from msdb..sysjobs 
END


IF (SELECT count(enabled) FROM SQLJobsBase WHERE enabled = 1) > (select count(enabled) from msdb..sysjobs WHERE enabled = 1)
 BEGIN 
WITH DisableTable
AS
(
select name, enabled
from SQLJobsBase
except
select name, enabled
from msdb..sysjobs 
)

SELECT name,enabled
INTO #DisabledTable
FROM DisableTable

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT name AS ''td'','''', ''Job '' + ''['' + name + '']'' +  '' has been disabled!!!'' AS ''td'',''''			
FROM #DisabledTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Agent Job Disabled</H3>
<table border = 1> 
<tr>
<th> name </th> <th> comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Agent Job Disabled'';
DROP TABLE #DisabledTable
EXEC UpdateSQLJobsBase
END
GO
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check_if_job_enabled]    Script Date: 08.03.2024 09:48:02 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_if_job_enabled', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'if EXISTS ( select 1 from SQLJobsBase)
BEGIN
PRINT ''SQLJobBase is updated''
END
ELSE
BEGIn
insert INTO SQLJobsBase(name,enabled)
SELECT name, enabled 
from msdb..sysjobs 
END

IF (SELECT count(enabled) FROM SQLJobsBase WHERE enabled = 1) < (select count(enabled) from msdb..sysjobs WHERE enabled = 1)
 BEGIN 
WITH EnabledTable
AS
(
select name, enabled
from SQLJobsBase
except
select name, enabled
from msdb..sysjobs 
)

SELECT name,enabled
INTO #EnabledTable
FROM EnabledTable

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT name AS ''td'','''', ''Job '' + ''['' + name + '']'' +  '' has been enabled!!!'' AS ''td'',''''			
FROM #EnabledTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Agent Job Enabled</H3>
<table border = 1> 
<tr>
<th> name </th> <th> comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Agent Job Enabled'';
DROP TABLE #EnabledTable
EXEC UpdateSQLJobsBase
END
GO
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
		@freq_subday_interval=3, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240301, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, 
		@schedule_uid=N'd8803a33-2ed4-4db7-acc2-412714abf4d0'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


