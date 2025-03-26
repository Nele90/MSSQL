USE [msdb]
GO

/****** Object:  Job [DBA: SQL services monitoring]    Script Date: 20.02.2024 12:58:48 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 20.02.2024 12:58:48 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL services monitoring', 
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
/****** Object:  Step [Get_services_info]    Script Date: 20.02.2024 12:58:49 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Get_services_info', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Get-Service -ComputerName localhost | ? {$_.DisplayName -like ''SQL*''} | select status, name, displayname | Export-Csv  -Path C:\temp\SQL_services_base.csv -NoTypeInformation', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [create base table and fill it]    Script Date: 20.02.2024 12:58:49 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'create base table and fill it', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF OBJECT_ID(N''dbo.sqlservicesbase'', N''U'') IS NOT NULL
BEGIN
    PRINT ''Table Exists''
END
ELSE 
BEGIN
	USE [DBA_DB]
	create table sqlservicesbase
		(
		Status nvarchar(20),
		Name nvarchar(50),
		DisplayName nvarchar(200)
		) ON [PRIMARY]
--fill base table

BULK INSERT sqlservicesbase
from ''C:\temp\SQL_services_base.csv''
with (firstrow = 2,
      fieldterminator = '','',
      rowterminator=''\n'',
      batchsize=10000,
      maxerrors=10);
END
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Get_processes_for_temptbl]    Script Date: 20.02.2024 12:58:49 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Get_processes_for_temptbl', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Get-Service -ComputerName localhost | ? {$_.DisplayName -like ''SQL*''} | select status, name, displayname | Export-Csv  -Path C:\temp\SQL_services_temp.csv -NoTypeInformation
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Create and fill comparetbl]    Script Date: 20.02.2024 12:58:49 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Create and fill comparetbl', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB
create table sqlservicestemp
(
Status nvarchar(20),
Name nvarchar(50),
DisplayName nvarchar(200)
)
GO

BULK INSERT sqlservicestemp
from ''C:\temp\SQL_services_temp.csv''
with (firstrow = 2,
      fieldterminator = '','',
      rowterminator=''\n'',
      batchsize=10000,
      maxerrors=10);

GO', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Compare_base_tmpd_and_send_email]    Script Date: 20.02.2024 12:58:49 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Compare_base_tmpd_and_send_email', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N';WITH CheckServicesStopped
AS
(
	  select REPLACE(status, ''"'', '''') as status, REPLACE(name, ''"'', '''') as name , REPLACE(displayname, ''"'', '''') as displayname
	  from sqlservicestemp
EXCEPT 
	  select REPLACE(status, ''"'', '''') as status, REPLACE(name, ''"'', '''') as name , REPLACE(displayname, ''"'', '''') as displayname
	  from sqlservicesbase
)

SELECT *, ''Chek why '' + name + '' has been '' + status as comment
INTO #CheckServicesStopped
FROM CheckServicesStopped

IF EXISTS (SELECT 1 FROM #CheckServicesStopped) 
 BEGIN 
--Send email 
	DECLARE @xml NVARCHAR(MAX)
	DECLARE @body NVARCHAR(MAX) 

	SET @xml = CAST (( SELECT status AS ''td'','''', name AS ''td'','''', displayname AS ''td'','''' ,  comment AS ''td'',''''
	From #CheckServicesStopped
	FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

	SET @body =''<html><body><H3>New Sysadmin Login</H3>
	<table border = 1> 
	<tr>
	<th> login </th> <th> status </th> <th> displayname </th> <th> comment </th>''    


	SET @body = @body + @xml +''</table></body></html>''

	EXEC msdb.dbo.sp_send_dbmail
	@profile_name = ''SQL_DBA_mail'',
	@body = @body,
	@body_format =''HTML'',
	@recipients = ''provide your email address'',
	@subject = ''New Sysadmin Logins'';

    DROP TABLE sqlservicestemp
END
ELSE 
BEGIN
	 DROP TABLE sqlservicestemp
END
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailit at 8am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240220, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, 
		@schedule_uid=N'cdebe35a-213a-47df-b4b8-06d261f62c1e'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


