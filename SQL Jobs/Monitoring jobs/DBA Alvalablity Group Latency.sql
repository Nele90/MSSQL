USE [msdb]
GO

/****** Object:  Job [DBA: Avalability group latency]    Script Date: 01.03.2024 11:30:39 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 01.03.2024 11:30:40 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Avalability group latency', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check_avalablity_group_latency]    Script Date: 01.03.2024 11:30:40 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_avalablity_group_latency', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @AGname NVARCHAR(128)
DECLARE @SecondaryReplicasOnly BIT
SET @AGname = (SELECT DISTINCT [name] AS AGName FROM sys.availability_groups_cluster)
IF OBJECT_ID(''TempDB..#tmpag_availability_groups'') IS NOT NULL
DROP TABLE [#tmpag_availability_groups];
 
SELECT *
INTO [#tmpag_availability_groups]
FROM   [master].[sys].[availability_groups];
 
IF(@AGname IS NULL
OR EXISTS
(
SELECT [Name]
FROM   [#tmpag_availability_groups]
WHERE  [Name] = @AGname
))
IF OBJECT_ID(''TempDB..#tmpdbr_availability_replicas'') IS NOT NULL
DROP TABLE [#tmpdbr_availability_replicas];
 
IF OBJECT_ID(''TempDB..#tmpdbr_database_replica_cluster_states'') IS NOT NULL
DROP TABLE [#tmpdbr_database_replica_cluster_states];
 
IF OBJECT_ID(''TempDB..#tmpdbr_database_replica_states'') IS NOT NULL
DROP TABLE [#tmpdbr_database_replica_states];
 
IF OBJECT_ID(''TempDB..#tmpdbr_database_replica_states_primary_LCT'') IS NOT NULL
DROP TABLE [#tmpdbr_database_replica_states_primary_LCT];
 
IF OBJECT_ID(''TempDB..#tmpdbr_availability_replica_states'') IS NOT NULL
DROP TABLE [#tmpdbr_availability_replica_states];
 
SELECT [group_id],
[replica_id],
[replica_server_name],
[availability_mode],
[availability_mode_desc]
INTO [#tmpdbr_availability_replicas]
FROM   [master].[sys].[availability_replicas];


SELECT [replica_id],
[group_database_id],
[database_name],
[is_database_joined],
[is_failover_ready]
INTO [#tmpdbr_database_replica_cluster_states]
FROM   [master].[sys].[dm_hadr_database_replica_cluster_states];
 
SELECT *
INTO [#tmpdbr_database_replica_states]
FROM   [master].[sys].[dm_hadr_database_replica_states];
 
SELECT [replica_id],
[role],
[role_desc],
[is_local]
INTO [#tmpdbr_availability_replica_states]
FROM   [master].[sys].[dm_hadr_availability_replica_states];
 
SELECT [ars].[role],
[drs].[database_id],
[drs].[replica_id],
[drs].[last_commit_time]
INTO [#tmpdbr_database_replica_states_primary_LCT]
FROM   [#tmpdbr_database_replica_states] AS [drs]
LEFT JOIN [#tmpdbr_availability_replica_states] [ars] ON [drs].[replica_id] = [ars].[replica_id]
WHERE  [ars].[role] = 1;
 
SELECT [AG].[name] AS [AvailabilityGroupName],
[AR].[replica_server_name] AS [AvailabilityReplicaServerName],
[dbcs].[database_name] AS [AvailabilityDatabaseName],
CASE [dbcs].[is_failover_ready]
WHEN 1
THEN 0
ELSE ISNULL(DATEDIFF([ss],[dbr].[last_commit_time],[dbrp].[last_commit_time]),0)
END AS [EstimatedDataLoss_(Seconds)],
ISNULL(CASE [dbr].[redo_rate]
WHEN 0
THEN-1
ELSE CAST([dbr].[redo_queue_size] AS FLOAT) / [dbr].[redo_rate]
END,-1) AS [EstimatedRecoveryTime_(Seconds)],
ISNULL([dbr].[is_suspended],0) AS [IsSuspended]
INTO #Finaltbl
FROM   [#tmpag_availability_groups] AS [AG]
INNER JOIN [#tmpdbr_availability_replicas] AS [AR] ON [AR].[group_id] = [AG].[group_id]
INNER JOIN [#tmpdbr_database_replica_cluster_states] AS [dbcs] ON [dbcs].[replica_id] = [AR].[replica_id]
LEFT OUTER JOIN [#tmpdbr_database_replica_states] AS [dbr] ON [dbcs].[replica_id] = [dbr].[replica_id]
AND [dbcs].[group_database_id] = [dbr].[group_database_id]
LEFT OUTER JOIN [#tmpdbr_database_replica_states_primary_LCT] AS [dbrp] ON [dbr].[database_id] = [dbrp].[database_id]
INNER JOIN [#tmpdbr_availability_replica_states] AS [arstates] ON [arstates].[replica_id] = [AR].[replica_id]
WHERE  [AG].[name] = ISNULL(@AGname,[AG].[name])
ORDER BY [AvailabilityReplicaServerName] ASC,
[AvailabilityDatabaseName] ASC;


IF EXISTS (SELECT * from #Finaltbl where [EstimatedDataLoss_(Seconds)] > 5 or [EstimatedRecoveryTime_(Seconds)] > 5 or IsSuspended = 1) 
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT AvailabilityGroupName AS ''td'','''',  AvailabilityReplicaServerName AS ''td'','''', AvailabilityDatabaseName AS ''td'','''', [EstimatedDataLoss_(Seconds)] AS ''td'','''' , [EstimatedRecoveryTime_(Seconds)] AS ''td'','''', IsSuspended AS ''td'',''''
FROM #Finaltbl
--where [EstimatedDataLoss_(Seconds)] > 5 or [EstimatedRecoveryTime_(Seconds)] > 5 or IsSuspended = 1
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))


SET @body =''<html><body><H3>SQL Always On Latency Check</H3>
<table border = 1> 
<tr>
<th> AvailabilityGroupName </th> <th> AvailabilityReplicaServerName </th> <th>  AvailabilityDatabaseName </th> <th>  [EstimatedDataLoss_(Seconds)] </th> <th>  [EstimatedRecoveryTime_(Seconds)] </th> <th>  IsSuspended </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Always On Latency Check'';
END

ELSE 
BEGIN
-- Drop the temporary table  
PRINT ''Always on latency is good''
END

DROP TABLE #Finaltbl
GO
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240301, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'1ed3dd18-12d4-4121-9c91-94805b4a71da'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


