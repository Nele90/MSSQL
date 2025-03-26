USE [msdb]
GO

/****** Object:  Job [DBA: SQL SSRS report status]    Script Date: 25.03.2024 15:33:20 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 25.03.2024 15:33:21 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL SSRS report status', 
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
/****** Object:  Step [Check report statys]    Script Date: 25.03.2024 15:33:21 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check report statys', 
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

SET @role = ( select role_desc 
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
DROP TABLE IF EXISTS #SQLReportTemp
DROP TABLE IF EXISTS #CreatedReport
DROP TABLE IF EXISTS #DeletedReport

SELECT 
  C.Name, 
  C.Path, 
  u.UserName,
  C.CreationDate
INTO #SQLReportTemp
FROM ReportServer..Catalog as c
INNER JOIN ReportServer..Users as u
ON c.CreatedByID = u.UserID
WHERE c.Type = 2


--Created new report
IF (SELECT COUNT(*)FROM SQLReportBase) < (SELECT COUNT(*)FROM #SQLReportTemp)
BEGIN
;WITH
CreatedReport
AS
(
SELECT *
FROM #SQLReportTemp
EXCEPT
SELECT *
FROM SQLReportBase
)
SELECT *
INTO #CreatedReport
FROM CreatedReport

DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT @@SERVERNAME AS ''td'','''',  CONVERT(varchar,CreationDate,21) AS ''td'','''', name AS ''td'','''',  Path AS ''td'','''', UserName AS ''td'','''', ''New Report: '' + ''['' + name + '']'' +'' has been created by '' +  ''['' + UserName + '']'' AS ''td'',''''			
FROM #CreatedReport
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL SSRS report status</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> CreateDate </th> <th> ReportName </th> <th> ReportPath </th> <th> WhoCreatedReport </th> <th> Comment </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL SSRS report status''
exec UpdateSQLReportBase


--Deleted new report
IF (SELECT COUNT(*)FROM SQLReportBase) > (SELECT COUNT(*)FROM #SQLReportTemp)
BEGIN
;WITH
DeletedReport
AS
(
SELECT *
FROM SQLReportBase
EXCEPT
SELECT *
FROM #SQLReportTemp
)
SELECT *
INTO #DeletedReport
FROM DeletedReport

DECLARE @xml1 NVARCHAR(MAX)
DECLARE @body1 NVARCHAR(MAX)

SET @xml1 = CAST (( SELECT @@SERVERNAME AS ''td'','''',  name AS ''td'','''',  Path AS ''td'','''', UserName AS ''td'','''', ''Report: '' + ''['' + name + '']'' +'' has been deleted!!'' AS ''td'',''''			
FROM #DeletedReport
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body1 =''<html><body><H3>SQL SSRS report status</H3>
<table border = 1> 
<tr>
<th> InstanceName </th> <th> ReportName </th> <th> ReportPath </th> <th> WhoCreatedReport </th> <th> Comment </th>''    


SET @body1 = @body1 + @xml1 +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL SSRS report status''
exec UpdateSQLReportBase
END
END
END
', 
		@database_name=N'DBA_DB', 
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
		@active_start_date=20240325, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'8591f1d6-cfcc-4d1e-b2a8-768c14b15d88'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


