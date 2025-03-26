USE [msdb]
GO

/****** Object:  Job [DBA: SQL Update Checker]    Script Date: 2/27/2024 10:39:01 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 2/27/2024 10:39:01 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Update Checker', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ckeck for update]    Script Date: 2/27/2024 10:39:02 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ckeck for update', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'PowerShell -ExecutionPolicy Bypass -File "C:\Temp\SQL_update_checker.ps1"', 
		@flags=0, 
		@proxy_name=N'SQL_update_checker'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [send email with SQL updates info]    Script Date: 2/27/2024 10:39:02 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'send email with SQL updates info', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
SELECT Build,	BuildLevel,	BuildTarget, 	Compliant, ISNULL(CULevel,''CU0'') as CULevel, ISNULL(CUTarget,''CU0'') as CUTarget,	KBLevel	,MatchType	,MaxBehind	,NameLevel,	SPLevel,	
SPTarget,	SqlInstance	,SupportedUntil	,Warning, InsertDate
INTO #True
FROM SQL_Updates
WHERE Compliant = ''True''


SELECT Build,	BuildLevel,	BuildTarget, 	Compliant, ISNULL(CULevel,''CU0'') as CULevel, ISNULL(CUTarget,''CU0'') as CUTarget, KBLevel ,MatchType	,MaxBehind	,NameLevel,	SPLevel,	
SPTarget,	SqlInstance	,SupportedUntil	,Warning,
CASE 
	WHEN NameLevel = 2019 and CULevel IS NULL  and CUTarget = ''CU25'' THEN ''5033688''
	ELSE KBLevel
	END as KBLevelFix, InsertDate
INTO #False
FROM SQL_Updates
WHERE Compliant = ''False''

;WITH OneTable
AS
(
SELECT Build,BuildLevel,	BuildTarget, Compliant,CULevel,CUTarget,KBLevelFix,MatchType,MaxBehind,NameLevel,SPLevel,	
SPTarget,SqlInstance,SupportedUntil	,Warning, InsertDate
FROM #False
UNION 
SELECT Build,BuildLevel,BuildTarget, Compliant,CULevel,CUTarget,KBLevel,MatchType,MaxBehind	,NameLevel,	SPLevel,	
SPTarget,SqlInstance,SupportedUntil	,Warning, InsertDate
FROM #True
)
SELECT *
INTO #FinalTable
FROM OneTable

DECLARE @xml NVARCHAR(MAX)
declare @body varchar(max)


SET @xml = CAST (( SELECT 	CASE WHEN Compliant = ''False'' THEN convert(XML,concat(''<font color="red">'',SqlInstance,''</font>''))
	WHEN Compliant = ''True'' THEN convert(XML,concat(''<font color="green">'',SqlInstance,''</font>''))
	END AS ''td'',''''
,  BuildLevel AS ''td'','''', BuildTarget AS ''td'','''' ,CASE 
	WHEN Compliant = ''False'' THEN convert(XML,concat(''<font color="red">'',Compliant,''</font>''))
	WHEN Compliant = ''True'' THEN convert(XML,concat(''<font color="green">'',Compliant,''</font>''))
	END AS ''td'','''' , CULevel AS ''td'','''', CUTarget AS ''td'','''' , SPLevel AS ''td'','''' , SPTarget AS ''td'','''' , NameLevel AS ''td'','''' , KBLevelFix AS ''td'','''', CONVERT(nvarchar, SupportedUntil, 21) AS ''td'',''''			
,CASE
	WHEN Compliant = ''False'' THEN convert(XML,concat(''<font color="red">'',''SQL is missing '' + SPTarget + '' or '' +  CUTarget ,''</font>'')) 
	WHEN Compliant = ''True'' THEN convert(XML,concat(''<font color="green">'',''SQL is not missing any update'',''</font>''))
	END AS ''td'',''''
FROM #FinalTable
WHERE InsertDate > DATEADD(Month, -1, GETDATE())
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Updates Check</H3>
<table border = 1> 
<tr>
<th> SqlInstance </th> <th> BuildLevel </th> <th>  BuildTarget </th> <th>  Compliant </th> <th>  CULevel </th> <th>  CUTarget </th> <th>  SPLevel </th> <th>  SPTarget </th> <th>  NameLevel </th> <th>  KBLevel </th> <th>  SupportedUntil </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address;'',
@subject = ''SQL Updates Check'';


DROP TABLE #False
DROP TABLE #True
DROP TABLE #FinalTable
GO


', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Montly', 
		@enabled=1, 
		@freq_type=32, 
		@freq_interval=8, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=1, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240301, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, 
		@schedule_uid=N'7aece0f4-6851-4a69-80cc-fbaf60e68e09'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


