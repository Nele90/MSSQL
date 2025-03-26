USE [msdb]
GO

/****** Object:  Job [DBA: SQL Login Status Check]    Script Date: 21.03.2024 08:38:23 ******/
EXEC msdb.dbo.sp_delete_job @job_name=N'DBA: SQL Login Status Check', @delete_unused_schedule=1
GO

/****** Object:  Job [DBA: SQL Login Status Check]    Script Date: 21.03.2024 08:38:23 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 21.03.2024 08:38:23 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Login Status Check', 
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
/****** Object:  Step [Check Login status]    Script Date: 21.03.2024 08:38:24 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check Login status', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB
--Fill SQLLogin StatusBase table
if EXISTS ( select 1 from SQLJobsBase)
BEGIN
PRINT ''SQLLoginStatusBase is updated''
END
ELSE
BEGIn
insert INTO SQLJobsBase(name,enabled)
SELECT name, is_disabled 
FROM sys.server_principals
END

--Check if login is created
IF (select count(name) from sys.server_principals ) > (SELECT count(name) FROM SQLLoginStatusBase)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT name AS ''td'','''', ''New Login '' + ''['' +name + '']'' +'' has been created!!!'' AS ''td'',''''			
FROM sys.server_principals  
WHERE create_date > DATEADD(Hour, -4, getdate())
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Login Status Creation</H3>
<table border = 1> 
<tr>
<th> NewLoginName </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Login Status Creation'';
EXEC UpdateSQLLoginBase
END
GO
--Check if login is deleted
IF (select count(name) from sys.server_principals ) < (SELECT count(name) FROM SQLLoginStatusBase)
 BEGIN 
WITH DeleteTable
AS
(
select name
from SQLLoginStatusBase
except
select name
from sys.server_principals  
)

SELECT name
INTO #DelteTable
FROM DeleteTable

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT name AS ''td'','''', ''Login '' + ''['' + name + '']'' +  '' has been deleted!!!'' AS ''td'',''''			
FROM #DelteTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Login Status Deletion</H3>
<table border = 1> 
<tr>
<th> LoginName </th> <th> comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Login Status Deletion'';
DROP TABLE #DelteTable
EXEC UpdateSQLLoginBase
END
GO

--Check if login is enabled
IF (SELECT count(is_disabled) FROM SQLLoginStatusBase WHERE is_disabled = 1) > (select count(is_disabled) from sys.server_principals  WHERE is_disabled = 1)
 BEGIN 
WITH EnableTable
AS
(
select name, is_disabled
from SQLLoginStatusBase
except
select name, is_disabled
from sys.server_principals  
)

SELECT name,is_disabled
INTO #EnableTable
FROM EnableTable

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT name AS ''td'','''', ''Login '' + ''['' + name + '']'' +  '' has been enabled!!!'' AS ''td'',''''			
FROM #EnableTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Login Status Enbled</H3>
<table border = 1> 
<tr>
<th> LoginName </th> <th> comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Login Status Enabled'';
DROP TABLE #EnableTable
EXEC UpdateSQLLoginBase
END
GO
--Check if login is disabled
IF (SELECT count(is_disabled) FROM SQLLoginStatusBase WHERE is_disabled = 1) < (select count(is_disabled) from sys.server_principals  WHERE is_disabled = 1)
 BEGIN 
WITH DisabledTable
AS
(
select name, is_disabled
from SQLLoginStatusBase
except
select name, is_disabled
from sys.server_principals  
)

SELECT name,is_disabled
INTO #DisabledTable
FROM DisabledTable

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT name AS ''td'','''', ''Job '' + ''['' + name + '']'' +  '' has been Disabled!!!'' AS ''td'',''''			
FROM #DisabledTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Login Status Disabled</H3>
<table border = 1> 
<tr>
<th> LoginName </th> <th> comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Login Status Disabled'';
DROP TABLE #DisabledTable
EXEC UpdateSQLLoginBase
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
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240304, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'3cb5e54a-6197-4c8a-8054-e79df7ab86a2'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


