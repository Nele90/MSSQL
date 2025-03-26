USE [msdb]
GO

/****** Object:  Job [DBA: tcprd14 data file size]    Script Date: 2/2/2024 11:32:44 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 2/2/2024 11:32:44 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: tcprd14 data file size', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Monitoring]', 
		@owner_login_name=N'owner name', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [chcek db file size]    Script Date: 2/2/2024 11:32:44 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'chcek db file size', 
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


;WITH DBsize
AS 
(
			SELECT     
			DB_NAME(db.database_id) DatabaseName,     
			(CAST(mfrows.RowSize AS FLOAT)*8)/1024 RowSizeMB,     
			(CAST(mflog.LogSize AS FLOAT)*8)/1024 LogSizeMB, 
			(CAST(mfrows.RowSize AS FLOAT)*8)/1024/1024+(CAST(mflog.LogSize AS FLOAT)*8)/1024/1024 DBSizeG,
			(CAST(mfstream.StreamSize AS FLOAT)*8)/1024 StreamSizeMB,    
			(CAST(mfrows.RowSize AS FLOAT)*8)/1024/1024 as DBsizeGB,
			(CAST(mftext.TextIndexSize AS FLOAT)*8)/1024 TextIndexSizeMB 
			FROM sys.databases db     
			LEFT JOIN (SELECT database_id, 
							  SUM(size) RowSize 
						FROM sys.master_files 
						WHERE type = 0 
						GROUP BY database_id, type) mfrows 
				ON mfrows.database_id = db.database_id     
			LEFT JOIN (SELECT database_id, 
							  SUM(size) LogSize 
						FROM sys.master_files 
						WHERE type = 1 
						GROUP BY database_id, type) mflog 
				ON mflog.database_id = db.database_id     
			LEFT JOIN (SELECT database_id, 
							  SUM(size) StreamSize 
							  FROM sys.master_files 
							  WHERE type = 2 
							  GROUP BY database_id, type) mfstream 
				ON mfstream.database_id = db.database_id     
			LEFT JOIN (SELECT database_id, 
							  SUM(size) TextIndexSize 
							  FROM sys.master_files 
							  WHERE type = 4 
							  GROUP BY database_id, type) mftext 
				ON mftext.database_id = db.database_id 
)
SELECT DatabaseName, DBsizeGB
INTO #FileSize
FROM DBsize
WHERE DatabaseName = ''tcprd14''



IF EXISTS (SELECT 1 FROM #FileSize)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT [DatabaseName] AS ''td'','''', CAST([DBsizeGB] as nvarchar(30)) AS ''td'',''''--, CAST([Log Space Used (%)] as nvarchar(30)) AS ''td'','''', Status AS ''td'',''''					
From #FileSize
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body = ''<html><body><H3>tcprd14 data file</H3>
<table border = 1> 
<tr>
<th> Database Name </th> <th> DBsizeGB </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address; '',
@subject = ''tcprd14 data file'';
END

ELSE
BEGIN
	PRINT ''This is secondary node''
END

IF @role = ''PRIMARY''
BEGIN
	DROP TABLE #FileSize
END
ELSE 
PRINT ''This is seconary node''
END', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'daily at 9 am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240104, 
		@active_end_date=99991231, 
		@active_start_time=90000, 
		@active_end_time=235959, 
		@schedule_uid=N'b1e85898-36f8-4424-b878-fb9dd2a54d60'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


