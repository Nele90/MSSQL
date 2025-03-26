USE [msdb]
GO

/****** Object:  Job [DBA: SQL Page Split Alert]    Script Date: 18.09.2024 09:35:52 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 18.09.2024 09:35:52 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Page Split Alert', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'dbamiadmin', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check page splits]    Script Date: 18.09.2024 09:35:53 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check page splits', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @PageSplits TABLE(
    InstanceName varchar(50) NULL,
    CounterID int NULL,
	[AVGPageSplits/S] decimal (5,2),
	CounterName varchar(20)
);

INSERT INTO @PageSplits (InstanceName,CounterID,[AVGPageSplits/S],CounterName)
SELECT I.Instance, PC.CounterID, AVG(PC.Value) AS [AVGPageSplits/S], C.counter_name
FROM PerformanceCounters as PC
INNER JOIN Counters AS C
ON PC.CounterID = C.CounterID
INNER JOIN Instances AS I
ON PC.InstanceID = I.InstanceID
WHERE PC.InstanceID IN (SELECT InstanceID FROM Instances) and PC.CounterID = 9 AND PC.SnapshotDate > DATEADD(DAY, -1, GETUTCDATE())  
Group by PC.CounterID , PC.InstanceID, C.counter_name, I.Instance

IF EXISTS (SELECT 1 FROM @PageSplits WHERE [AVGPageSplits/S] > 100)
BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST ((SELECT InstanceName AS ''td'','''', [AVGPageSplits/S] AS ''td'','''', ''High PageSplit detected!!'' AS ''td'',''''
FROM @PageSplits WHERE [AVGPageSplits/S] > 100
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>High SQL Page Split</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AVGPageSplits/S </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''High SQL Page Split'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''There is no High SQL Page Split''
END', 
		@database_name=N'DBADashDB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dailiy at 5am', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240918, 
		@active_end_date=99991231, 
		@active_start_time=50000, 
		@active_end_time=235959, 
		@schedule_uid=N'a6016bc1-7b5b-4dc7-b730-e7c39e8e3e32'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


