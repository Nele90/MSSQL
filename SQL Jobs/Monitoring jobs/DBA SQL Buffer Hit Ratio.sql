USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Buffer Hit Ratio', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: SQL Buffer Hit Ratio', @server_name = N'AZWEPRDSQLMI01.692CC530CC7C.DATABASE.WINDOWS.NET'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: SQL Buffer Hit Ratio', @step_name=N'Check low buffer hit ratio', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @BufferHitRatio TABLE(
    InstanceName varchar(50) NULL,
    CounterID int NULL,
	[AVGBufferHitRatio] decimal (5,2),
	CounterName varchar(30)
);

INSERT INTO @BufferHitRatio (InstanceName,CounterID,[AVGBufferHitRatio],CounterName)
SELECT I.Instance, PC.CounterID, AVG(PC.Value) AS [AVGBufferHitRatio], C.counter_name
FROM PerformanceCounters as PC
INNER JOIN Counters AS C
ON PC.CounterID = C.CounterID
INNER JOIN Instances AS I
ON PC.InstanceID = I.InstanceID
WHERE PC.InstanceID IN (SELECT InstanceID FROM Instances) and PC.CounterID = 10 AND PC.SnapshotDate > DATEADD(DAY, -1, GETUTCDATE())  
Group by PC.CounterID , PC.InstanceID, C.counter_name, I.Instance 


IF EXISTS (SELECT 1 FROM @BufferHitRatio WHERE [AVGBufferHitRatio] < 90)
BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST ((SELECT InstanceName AS ''td'','''', [AVGBufferHitRatio] AS ''td'','''', ''Low Buffer Hit Ratio, check for memory pressue!!!'' AS ''td'',''''
FROM @BufferHitRatio WHERE [AVGBufferHitRatio] < 90
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>Low Buffer Hit Ratio</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> AVGBufferHitRatio </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''Low Buffer Hit Ratio'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''There is no Low Buffer Hit Ratio''
END', 
		@database_name=N'DBADashDB', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA: SQL Buffer Hit Ratio', 
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
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: SQL Buffer Hit Ratio', @name=N'Dailiy 8am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20250124, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
