USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: Missing Indexes Monitoring', 
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
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: Missing Indexes Monitoring'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: Missing Indexes Monitoring', @step_name=N'Collect_missing_indexes', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'INSERT INTO MissingIndexes
SELECT 
GETDATE() AS InsertDate,
db_name(mid.database_id) AS DatabaseName,
OBJECT_SCHEMA_NAME (mid.OBJECT_ID,mid.database_id) AS [SchemaName],
OBJECT_NAME(mid.OBJECT_ID,mid.database_id) AS [TableName],
migs.user_seeks as [Estimated Index Uses],
migs.avg_user_impact [Estimated Index Impact %],
migs.avg_total_user_cost[Estimated Avg Query Cost], 
''CREATE INDEX [IX_'' + OBJECT_NAME(mid.OBJECT_ID,mid.database_id) + ''_''
+ REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns,''''),'', '',''_''),''['',''''),'']'','''') 
+ CASE
WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
THEN ''_''
ELSE ''''
  END
+ REPLACE(REPLACE(REPLACE(ISNULL(mid.inequality_columns,''''),'', '',''_''),''['',''''),'']'','''')
+ '']''
+ '' ON '' + mid.statement
+ '' ('' + ISNULL (mid.equality_columns,'''')
+ CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns 
IS NOT NULL THEN '','' ELSE
'''' END
+ ISNULL (mid.inequality_columns, '''')
+ '')''
+ ISNULL ('' INCLUDE ('' + mid.included_columns + '') WITH (MAXDOP =?, FILLFACTOR=?, ONLINE=?, SORT_IN_TEMPDB=?);'', '''') AS [Create TSQL],
mid.equality_columns, 
mid.inequality_columns, 
mid.included_columns,
migs.unique_compiles,
migs.last_user_seek
FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON mig.index_handle = mid.index_handle
ORDER BY [Estimated Index Uses] DESC OPTION (RECOMPILE);', 
		@database_name=N'DBA_DB', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA: Missing Indexes Monitoring', 
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
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: Missing Indexes Monitoring', @name=N'Dailiy at 4am', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20240517, 
		@active_end_date=99991231, 
		@active_start_time=40000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO
