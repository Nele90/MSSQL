USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Page Life Expectancy Monitoring', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'dbamiadmin', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: SQL Page Life Expectancy Monitoring', @server_name = N'AZWEPRDSQLMI01.692CC530CC7C.DATABASE.WINDOWS.NET'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: SQL Page Life Expectancy Monitoring', @step_name=N'Check PLE for last day', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBADashDB
DROP TABLE IF EXISTS #PLE

;WITH PLE
AS
(
SELECT AVG(C.Value) as PageLifeExpectancyAVG, I.Instance, MAX(CAST(SC.value_in_use as int)) as MaxMemoryValue
FROM PerformanceCounters as C
INNER JOIN Instances as I
ON C.InstanceID = I.InstanceID
INNER JOIN SysConfig AS SC
ON I.InstanceID = SC.InstanceID
WHERE CounterID = 14 and SnapshotDate > DATEADD(DAY, -1, GETUTCDATE()) and SC.configuration_id = 1544	and I.Instance NOT IN (''azweprdsqlmi01.692cc530cc7c.database.windows.net'',''SVR-PL-ELSF-01\SQLEXPRESS'',''SVR-PL-ISA-01\SQLEXPRESS'')
GROUP BY Instance
)
SELECT PageLifeExpectancyAVG, Instance,((MaxMemoryValue/1024)/4)*300 AS MaxMemoryValueGB
INTO #PLE
FROM PLE
WHERE PageLifeExpectancyAVG < ((MaxMemoryValue/1024)/4)*300

IF EXISTS (SELECT 1 FROM #PLE)

--Send email
BEGIN
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)



SET @xml = CAST (( SELECT Instance AS ''td'','''' ,CAST(PageLifeExpectancyAVG as decimal (10,2)) AS ''td'','''', MaxMemoryValueGB AS ''td'','''' , ''This is Microsoft recomneded value '' + CAST(MaxMemoryValueGB as varchar(20)) +  '' for PLE, Calucaltuon is done for last day'' AS ''td'',''''
FROM #PLE
WHERE MaxMemoryValueGB < 157286100
ORDER BY PageLifeExpectancyAVG DESC
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Page Life Expectancy</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> PageLifeExpectancyAVG </th> <th> DesiredValue </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Page Life Expectancy'';
END
GO', 
		@database_name=N'DBADashDB', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA: SQL Page Life Expectancy Monitoring', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'dbamiadmin', 
		@notify_email_operator_name=N'DBA_member', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: SQL Page Life Expectancy Monitoring', @name=N'Dailiy at 7am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240722, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
