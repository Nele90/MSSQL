USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Query Plan Compilation', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'dbamiadmin', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: SQL Query Plan Compilation', @server_name = N'AZWEPRDSQLMI01.692CC530CC7C.DATABASE.WINDOWS.NET'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: SQL Query Plan Compilation', @step_name=N'Check plan compilation', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DROP TABLE IF EXISTS #SQLCompilation

;WITH A
AS(
	SELECT PC.InstanceID, PC.CounterID, AVG(PC.Value) AS AVGVAlue, C.counter_name, I.Instance
	FROM PerformanceCounters as PC
	INNER JOIN Counters AS C
	ON PC.CounterID = C.CounterID
	INNER JOIN Instances AS I
	ON PC.InstanceID = I.InstanceID
	WHERE PC.InstanceID IN (SELECT InstanceID FROM Instances) and PC.CounterID IN (62,61) AND PC.SnapshotDate > DATEADD(DAY, -1, GETUTCDATE()) 
	Group by PC.CounterID , PC.InstanceID, C.counter_name, I.Instance
),  Batch AS
(
select InstanceID, CounterID, counter_name, CAST(AVGVAlue as decimal (6,2)) AS BatchAVG
from A 
where CounterID = 61
), Compilation 
AS
(
select  InstanceID, CounterID, counter_name,  CAST(AVGVAlue as decimal (6,2)) AS CompilationAVG, Instance
from A 
where CounterID = 62)
, Final 
AS(
SELECT C.Instance, C.CompilationAVG, B.BatchAVG,(C.CompilationAVG /B.BatchAVG)*100 as [Compilation/S]
FROM Compilation AS C
INNER JOIN Batch AS B
ON C.InstanceID = B.InstanceID 
)
SELECT Instance,CompilationAVG,BatchAVG, CAST(CAST([Compilation/S]as decimal (5,2)) as varchar(6)) + ''%'' as [Compilation/S%]
INTO #SQLCompilation
FROM Final
WHERE CompilationAVG > 6 AND BatchAVG > 6 AND [Compilation/S] > 50

IF EXISTS (SELECT 1 FROM #SQLCompilation)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST ((SELECT Instance AS ''td'','''',CompilationAVG AS ''td'','''',BatchAVG AS ''td'','''', [Compilation/S%] AS ''td'',''''
FROM #SQLCompilation
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>High SQL Query Paln Compilation</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> CompilationAVG/S </th> <th>  BatchAVG/S </th> <th>  Compilation/S% </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''High SQL Query Paln Compilation'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''There is no High SQL Query Paln Compilationg''
END
', 
		@database_name=N'DBADashDB', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA: SQL Query Plan Compilation', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'dbamiadmin', 
		@notify_email_operator_name=N'DBA_member', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: SQL Query Plan Compilation', @name=N'Dailiy at 6am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240912, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
