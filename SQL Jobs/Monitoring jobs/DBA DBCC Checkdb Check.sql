USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: DBCC checkdb check', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: DBCC checkdb check'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: DBCC checkdb check', @step_name=N'Check_last_dbcc_checkdb', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'CREATE TABLE #DBInfo (
       Id INT IDENTITY(1,1),
       ParentObject VARCHAR(255),
       [Object] VARCHAR(255),
       Field VARCHAR(255),
       [Value] VARCHAR(255)
)

CREATE TABLE #Value(
DatabaseName VARCHAR(255),
LastGoodDBCC VARCHAR(255)
)

EXECUTE SP_MSFOREACHDB''INSERT INTO #DBInfo Execute (''''DBCC DBINFO ( ''''''''?'''''''') WITH TABLERESULTS'''');
INSERT INTO #Value (DatabaseName) SELECT [Value] FROM #DBInfo WHERE Field IN (''''dbi_dbname'''');
UPDATE #Value SET LastGoodDBCC=(SELECT TOP 1 [Value] FROM #DBInfo WHERE Field IN (''''dbi_dbccLastKnownGood'''')) where LastGoodDBCC is NULL;
TRUNCATE TABLE #DBInfo'';

IF EXISTS (SELECT 1 FROM #Value WHERE DatabaseName not in (''tempdb'',''model'') and LastGoodDBCC < DATEADD(MONTH, -1, GETDATE())) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT DatabaseName AS ''td'','''',
CASE 
WHEN LastGoodDBCC < DATEADD(MONTH, -1, GETDATE()) THEN convert(XML,concat(''<font color="red">'',LastGoodDBCC,''</font>'')) END AS ''td'','''' 
,  ''DBCC check db is not done for database '' + DatabaseName + '' please run DBCC CHECKDB (''+ '''''''' +DatabaseName+ '''''''' + '')!!'' AS ''td'',''''
FROM #Value
WHERE DatabaseName not in (''tempdb'',''model'') and LastGoodDBCC < DATEADD(MONTH, -1, GETDATE())
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))



SET @body =''<html><body><H3>DBCC checkdb check</H3>
<table border = 1> 
<tr>
<th> DatabaseName </th> <th> LastGoodDBCC </th>  <th> Comment </th> ''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address;'',
@subject = ''DBCC checkdb check'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''DBCC checkdb is done on regural basic''
END
DROP TABLE #DBInfo
DROP TABLE #Value', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA: DBCC checkdb check', 
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
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: DBCC checkdb check', @name=N'Montly', 
		@enabled=1, 
		@freq_type=16, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240228, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
