USE [msdb]
GO

/****** Object:  Job [DBA: SQL CPU Utilization Check]    Script Date: 27.03.2024 15:31:00 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 27.03.2024 15:31:01 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL CPU Utilization Check', 
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
/****** Object:  Step [Check high CPU usage for last 30 min]    Script Date: 27.03.2024 15:31:02 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check high CPU usage for last 30 min', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DROP TABLE IF EXISTS #HighAvgCPU

;WITH AVGCPU
AS
(
SELECT I.Instance, SUM(C.SumTotalCPU*1.0)/SUM(C.SampleCount*1.0) AS AvgCPU
FROM [DBADashDB].[dbo].[CPU] as c
inner join Instances as i
on c.InstanceID = i.InstanceID
WHERE c.EventTime > DATEADD(MINUTE, -30, GETUTCDATE())
GROUP BY I.Instance
)
SELECT Instance, CAST(AvgCPU as decimal(4,2)) AS AvgCPU
INTO #HighAvgCPU
FROM AVGCPU
WHERE AVGCPU > 90
GO

IF EXISTS (SELECT 1 FROM #HighAvgCPU) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT Instance AS ''td'','''', convert(XML,concat(''<font color="red">'',AvgCPU,''</font>'')) AS ''td'','''', ''CPU is ''+ CAST(AvgCPU as nvarchar(10))+'' for the last 30 min check DBADash to see why CPU is so high''	AS ''td'',''''
FROM #HighAvgCPU
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL CPU Utilization</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AvgCPU </th> <th>  Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address;;'',
@subject = ''SQL CPU Utilization'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''There is no high CPU utilization for the last 30 min''
END
GO
', 
		@database_name=N'DBADashDB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every 30 min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240327, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'032ea65f-1448-4c97-a874-55059cf7d178'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


