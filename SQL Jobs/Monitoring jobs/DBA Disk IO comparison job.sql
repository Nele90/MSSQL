USE [msdb]
GO

/****** Object:  Job [DBA: Disk IO Stats Comparions]    Script Date: 1/17/2021 22:30:14 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 1/17/2021 22:30:14 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Disk IO Stats Comparions', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'owner name', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Fill comparison table]    Script Date: 1/17/2021 22:30:14 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Fill comparison table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB

--Job two is to create table to compare with base line at 4pm
SELECT GETDATE () AS CheckDate, [database_id], [file_id], [num_of_reads], [io_stall_read_ms],
	   [num_of_writes], [io_stall_write_ms], [io_stall],
	   [num_of_bytes_read], [num_of_bytes_written], [file_handle]
INTO IOCompareWithTBL
FROM sys.dm_io_virtual_file_stats (NULL, NULL);
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Compare stats and inset into stats table]    Script Date: 1/17/2021 22:30:14 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Compare stats and inset into stats table', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB

WITH [DiffLatencies] AS
(SELECT
-- Files that weren''t in the first snapshot
        [ts2].[database_id],
        [ts2].[file_id],
        [ts2].[num_of_reads],
        [ts2].[io_stall_read_ms],
		[ts2].[num_of_writes],
		[ts2].[io_stall_write_ms],
		[ts2].[io_stall],
		[ts2].[num_of_bytes_read],
		[ts2].[num_of_bytes_written]
    FROM IOCompareWithTBL AS [ts2]
    LEFT OUTER JOIN IOBaselineTbl AS [ts1]
        ON [ts2].[file_handle] = [ts1].[file_handle]
    WHERE [ts1].[file_handle] IS NULL
UNION
SELECT
-- Diff of latencies in both snapshots
        [ts2].[database_id],
        [ts2].[file_id],
        [ts2].[num_of_reads] - [ts1].[num_of_reads] AS [num_of_reads],
        [ts2].[io_stall_read_ms] - [ts1].[io_stall_read_ms] AS [io_stall_read_ms],
		[ts2].[num_of_writes] - [ts1].[num_of_writes] AS [num_of_writes],
		[ts2].[io_stall_write_ms] - [ts1].[io_stall_write_ms] AS [io_stall_write_ms],
		[ts2].[io_stall] - [ts1].[io_stall] AS [io_stall],
		[ts2].[num_of_bytes_read] - [ts1].[num_of_bytes_read] AS [num_of_bytes_read],
		[ts2].[num_of_bytes_written] - [ts1].[num_of_bytes_written] AS [num_of_bytes_written]
    FROM IOCompareWithTBL AS [ts2]
    LEFT OUTER JOIN IOBaselineTbl AS [ts1]
        ON [ts2].[file_handle] = [ts1].[file_handle]
    WHERE [ts1].[file_handle] IS NOT NULL)
INSERT INTO DiskIOStats
SELECT
	GETDATE() AS CheckDate,
	DB_NAME ([vfs].[database_id]) AS [DB],
	LEFT ([mf].[physical_name], 2) AS [Drive],
	[mf].[type_desc],
	[num_of_reads] AS [Reads],
	[num_of_writes] AS [Writes],
	[ReadLatency(ms)] =
		CASE WHEN [num_of_reads] = 0
			THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
	[WriteLatency(ms)] =
		CASE WHEN [num_of_writes] = 0
			THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
	 [Latency] =
		 CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
			 THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
	[AvgBPerRead] =
		CASE WHEN [num_of_reads] = 0
			THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
	[AvgBPerWrite] =
		CASE WHEN [num_of_writes] = 0
			THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
	 [AvgBPerTransfer] =
		 CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
			 THEN 0 ELSE
				 (([num_of_bytes_read] + [num_of_bytes_written]) /
				 ([num_of_reads] + [num_of_writes])) END,
	[mf].[physical_name]
FROM [DiffLatencies] AS [vfs]
JOIN sys.master_files AS [mf]
	ON [vfs].[database_id] = [mf].[database_id]
	AND [vfs].[file_id] = [mf].[file_id]
-- ORDER BY [ReadLatency(ms)] DESC
ORDER BY [WriteLatency(ms)] DESC;
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Send Email]    Script Date: 1/17/2021 22:30:14 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Send Email', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE DBA_DB

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)
SET @xml = CAST (( SELECT DB ''td'','''', Drive ''td'','''', type_desc ''td'','''', Reads ''td'','''', Writes ''td'','''', [ReadLatency(ms)] ''td'','''', [WriteLatency(ms)] ''td'','''',
					AvgBPerRead ''td'','''', AvgBPerWrite ''td'','''', physical_name ''td'',''''
FROM DiskIOStats 
WHERE CheckDate > DATEADD(hh, -1, GETDATE())
ORDER BY [WriteLatency(ms)] DESC
FOR XML PATH(''tr''), ELEMENTS ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>Tennis Rankings Info</H3>
<table border = 1> 
<tr>
<th> DB </th> <th> Drive </th> <th> type_desc </th> <th> Reads </th> <th> Writes </th> <th> ReadLatency(ms) </th> <th> WriteLatency(ms) </th> <th> AvgBPerRead </th> <th> AvgBPerWrite </th> <th> physical_name </th></tr>''    

SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''Mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''nenadradevic90@gmail.com'',
@subject = ''Disk IO Stats'';
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Dailiy at 3:50pm', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210117, 
		@active_end_date=99991231, 
		@active_start_time=155000, 
		@active_end_time=235959, 
		@schedule_uid=N'8a4256d1-3f08-4389-b5ab-3a118198fbe2'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
