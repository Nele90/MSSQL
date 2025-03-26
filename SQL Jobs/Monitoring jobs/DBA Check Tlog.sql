USE [msdb]
GO

/****** Object:  Job [DBA: Check Tlog]    Script Date: 3/8/2023 12:47:28 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 3/8/2023 12:47:28 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Check Tlog', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'sma\radevic_admin', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [check if some tlog is full than 90%]    Script Date: 3/8/2023 12:47:28 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check if some tlog is full than 90%', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @role VARCHAR(10)
DECLARE @availability_mode int

SET @role = (	select role_desc 
		from 
		sys.dm_hadr_availability_replica_cluster_states rcs
		INNER JOIN sys.dm_hadr_availability_replica_states ars ON rcs.replica_id = ars.replica_id
		WHERE replica_server_name = @@SERVERNAME
	     )

 SET @availability_mode = (	
 
 SELECT availability_mode FROM sys.availability_replicas WHERE replica_server_name = @@SERVERNAME
	    )

IF @role = ''PRIMARY''
BEGIN
USE master

CREATE TABLE #logspace
( [Database Name] sysname
, [Log Size (MB)] float
, [Log Space Used (%)] float
, Status int);



INSERT INTO #logspace
EXEC (''DBCC SQLPERF(LOGSPACE);'')

IF EXISTS (SELECT 1 FROM #logspace WHERE [Log Space Used (%)] > 80 and [Log Size (MB)]  > 10524) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT [Database Name] AS ''td'','''', CAST([Log Size (MB)] as nvarchar(30)) AS ''td'','''', CAST([Log Space Used (%)] as nvarchar(30)) AS ''td'','''', Status AS ''td'',''''					
From #logspace
WHERE [Log Space Used (%)] > 80 and [Log Size (MB)]  > 10524
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>Database Tlog status</H3>
<table border = 1> 
<tr>
<th> Database Name </th> <th> Log Size (MB) </th> <th> Log Space Used (%) </th> <th> Status </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''Database Tlog status'';
END

ELSE 
BEGIN
-- Drop the temporary table  
DROP TABLE #logspace
END
END
ELSE
BEGIN
	PRINT ''This is secondary and sync commit''
END
', 
		@database_name=N'master', 
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
		@active_start_date=20221021, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, 
		@schedule_uid=N'6254cfe6-c74e-45ae-bd23-77660dbca3bf'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
