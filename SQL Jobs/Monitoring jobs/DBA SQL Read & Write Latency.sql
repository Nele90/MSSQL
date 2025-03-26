USE [msdb]
GO

/****** Object:  Job [DBA: SQL Read & Write Latency]    Script Date: 6/18/2024 10:54:34 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 6/18/2024 10:54:34 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Read & Write Latency', 
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
/****** Object:  Step [Check_SQL_ read_write_latency]    Script Date: 6/18/2024 10:54:35 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_SQL_ read_write_latency', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DROP TABLE IF EXISTS #IOLatency 
GO

;WITH
LATENCY
AS
(
SELECT
			SUM(io_stall_read_ms)/(NULLIF(SUM(num_of_reads),0)*1) AS ReadLatency,
			SUM(io_stall_write_ms)/(NULLIF(SUM(num_of_writes),0)*1) AS WriteLatency,
			SnapshotDate,
			InstanceID
FROM DBIOStats 
WHERE cast(SnapshotDate AS datetime) > DATEADD(HOUR, -1, GETUTCDATE())
group by SnapshotDate, InstanceID
)

SELECT  MAX(I.Instance) AS InstanceName , 
				CASE 
				WHEN  AVG(L.ReadLatency) IS NULL THEN ''0''
				ELSE AVG(L.ReadLatency) END as ReadLatency, 
				CASE 
				WHEN AVG(L.WriteLatency) IS NULL THEN ''0''
				ELSE AVG(L.WriteLatency) END as WriteLatency
				
INTO #IOLatency
FROM LATENCY AS L
INNER JOIN Instances AS I
ON L.InstanceID = I.InstanceID
WHERE ReadLatency > 50 or WriteLatency > 50
GROUP BY L.InstanceID
GO


IF EXISTS (SELECT 1 FROM #IOLatency)
BEGIN
--Send Email
DECLARE @xml NVARCHAR(MAX)
declare @body varchar(max)

SET @xml = CAST (( SELECT InstanceName AS ''td'',''''

,CASE
	WHEN CAST(ReadLatency as nvarchar (5)) > 30 and CAST(ReadLatency as nvarchar (5)) < 60 THEN convert(XML,concat(''<font color="orange">'',CAST(ReadLatency as nvarchar (5)),''</font>'')) 
	WHEN CAST(ReadLatency as nvarchar (5)) > 60 THEN convert(XML,concat(''<font color="red">'',CAST(ReadLatency as nvarchar (5)),''</font>'')) 
	ELSE CAST(ReadLatency as nvarchar (5))
	END AS ''td'','''',
	CASE
	WHEN CAST(WriteLatency as nvarchar (5)) > 30 and CAST(WriteLatency as nvarchar (5)) < 60 THEN convert(XML,concat(''<font color="orange">'',CAST(WriteLatency as nvarchar (5)),''</font>'')) 
	WHEN CAST(WriteLatency as nvarchar (5)) > 60 THEN convert(XML,concat(''<font color="red">'',CAST(WriteLatency as nvarchar (5)),''</font>'')) 
	ELSE CAST(WriteLatency as nvarchar (5)) 
	END AS ''td'','''',
	''Avrage IO read and write latency for last 1 hour'' AS ''td'',''''
FROM #IOLatency
ORDER BY ReadLatency,WriteLatency
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>Disk Read & Write latency</H3>
<table border = 1> 
<tr>
<th> SqlInstance </th> <th> ReadLatency </th> <th>  WriteLatency </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''Disk Read & Write latency'';
END
GO
', 
		@database_name=N'DBADashDB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy every 1h', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240617, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'43f6ce6c-6aea-490d-939b-8f2423d70b98'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
