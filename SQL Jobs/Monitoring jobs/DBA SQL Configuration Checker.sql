USE [msdb]
GO

/****** Object:  Job [DBA: SQL Configuration Checker]    Script Date: 06.03.2024 12:16:26 ******/
EXEC msdb.dbo.sp_delete_job @job_name=N'DBA: SQL Configuration Checker', @delete_unused_schedule=1
GO

/****** Object:  Job [DBA: SQL Configuration Checker]    Script Date: 06.03.2024 12:16:26 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 06.03.2024 12:16:26 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Configuration Checker', 
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
/****** Object:  Step [Check_configuration]    Script Date: 06.03.2024 12:16:27 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_configuration', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N';WITH
CahgedValue
AS
(
SELECT *
from SQLConfigurationBase
EXCEPT
SELECT configuration_id ,name, value, minimum, maximum, value_in_use, description, is_dynamic,is_advanced
from sys.configurations
)
SELECT C.name, C.value_in_use as PreviousValue, B.value_in_use as NewValue, 
C.description, ''Configuration '' + ''['' +C.name + '']'' +'' has been '' + CASE WHEN CONVERT(nvarchar(20),B.value_in_use) = 1 THEN ''Enabled'' 
	WHEN CONVERT(nvarchar(20),B.value_in_use) = 0 THEN ''Disabled''
	WHEN CONVERT(nvarchar(20),B.value_in_use) NOT IN (1,0) THEN ''has been changed to '' + CONVERT(nvarchar(20),B.value_in_use)
	 END as Comment
into #FinalTable
FROM CahgedValue AS C
INNER JOIN sys.configurations AS B
ON C.configuration_id = B.configuration_id

if exists (select 1 from #FinalTable)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT name AS ''td'','''', PreviousValue AS ''td'','''', NewValue AS ''td'','''', Comment AS ''td'',''''	
FROM #FinalTable
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Configuration Checker</H3>
<table border = 1> 
<tr>
<th> ConfigbName </th> <th> PreviousValue </th> <th> NewValue </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Configuration Checker'';
EXEC UpdateSQLConfigurationBase
END
DROP TABLE #FinalTable', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dailiy', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240306, 
		@active_end_date=99991231, 
		@active_start_time=63000, 
		@active_end_time=235959, 
		@schedule_uid=N'bd6b0713-6e05-4a59-bdfb-51e887c610b2'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


