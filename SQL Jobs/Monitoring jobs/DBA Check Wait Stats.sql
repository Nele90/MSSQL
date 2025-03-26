USE [msdb]
GO

/****** Object:  Job [DBA: Check Wait Stats]    Script Date: 3/8/2023 12:49:16 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 3/8/2023 12:49:16 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Check Wait Stats', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'owner name', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Wait Stats]    Script Date: 3/8/2023 12:49:16 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Wait Stats', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'WITH [Waits] AS
    (SELECT
        [wait_type],
        [wait_time_ms] / 1000.0 AS [WaitS],
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
        [signal_wait_time_ms] / 1000.0 AS [SignalS],
        [waiting_tasks_count] AS [WaitCount],
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        -- These wait types are almost 100% never a problem and so they are
        -- filtered out to avoid them skewing the results. Click on the URL
        -- for more information.
        N''BROKER_EVENTHANDLER'', -- https://www.sqlskills.com/help/waits/BROKER_EVENTHANDLER
        N''BROKER_RECEIVE_WAITFOR'', -- https://www.sqlskills.com/help/waits/BROKER_RECEIVE_WAITFOR
        N''BROKER_TASK_STOP'', -- https://www.sqlskills.com/help/waits/BROKER_TASK_STOP
        N''BROKER_TO_FLUSH'', -- https://www.sqlskills.com/help/waits/BROKER_TO_FLUSH
        N''BROKER_TRANSMITTER'', -- https://www.sqlskills.com/help/waits/BROKER_TRANSMITTER
        N''CHECKPOINT_QUEUE'', -- https://www.sqlskills.com/help/waits/CHECKPOINT_QUEUE
        N''CHKPT'', -- https://www.sqlskills.com/help/waits/CHKPT
        N''CLR_AUTO_EVENT'', -- https://www.sqlskills.com/help/waits/CLR_AUTO_EVENT
        N''CLR_MANUAL_EVENT'', -- https://www.sqlskills.com/help/waits/CLR_MANUAL_EVENT
        N''CLR_SEMAPHORE'', -- https://www.sqlskills.com/help/waits/CLR_SEMAPHORE
 
        -- Maybe comment this out if you have parallelism issues
        N''CXCONSUMER'', -- https://www.sqlskills.com/help/waits/CXCONSUMER
 
        -- Maybe comment these four out if you have mirroring issues
        N''DBMIRROR_DBM_EVENT'', -- https://www.sqlskills.com/help/waits/DBMIRROR_DBM_EVENT
        N''DBMIRROR_EVENTS_QUEUE'', -- https://www.sqlskills.com/help/waits/DBMIRROR_EVENTS_QUEUE
        N''DBMIRROR_WORKER_QUEUE'', -- https://www.sqlskills.com/help/waits/DBMIRROR_WORKER_QUEUE
        N''DBMIRRORING_CMD'', -- https://www.sqlskills.com/help/waits/DBMIRRORING_CMD
        N''DIRTY_PAGE_POLL'', -- https://www.sqlskills.com/help/waits/DIRTY_PAGE_POLL
        N''DISPATCHER_QUEUE_SEMAPHORE'', -- https://www.sqlskills.com/help/waits/DISPATCHER_QUEUE_SEMAPHORE
        N''EXECSYNC'', -- https://www.sqlskills.com/help/waits/EXECSYNC
        N''FSAGENT'', -- https://www.sqlskills.com/help/waits/FSAGENT
        N''FT_IFTS_SCHEDULER_IDLE_WAIT'', -- https://www.sqlskills.com/help/waits/FT_IFTS_SCHEDULER_IDLE_WAIT
        N''FT_IFTSHC_MUTEX'', -- https://www.sqlskills.com/help/waits/FT_IFTSHC_MUTEX
  
       -- Maybe comment these six out if you have AG issues
        N''HADR_CLUSAPI_CALL'', -- https://www.sqlskills.com/help/waits/HADR_CLUSAPI_CALL
        N''HADR_FILESTREAM_IOMGR_IOCOMPLETION'', -- https://www.sqlskills.com/help/waits/HADR_FILESTREAM_IOMGR_IOCOMPLETION
        N''HADR_LOGCAPTURE_WAIT'', -- https://www.sqlskills.com/help/waits/HADR_LOGCAPTURE_WAIT
        N''HADR_NOTIFICATION_DEQUEUE'', -- https://www.sqlskills.com/help/waits/HADR_NOTIFICATION_DEQUEUE
        N''HADR_TIMER_TASK'', -- https://www.sqlskills.com/help/waits/HADR_TIMER_TASK
        N''HADR_WORK_QUEUE'', -- https://www.sqlskills.com/help/waits/HADR_WORK_QUEUE
 
        N''KSOURCE_WAKEUP'', -- https://www.sqlskills.com/help/waits/KSOURCE_WAKEUP
        N''LAZYWRITER_SLEEP'', -- https://www.sqlskills.com/help/waits/LAZYWRITER_SLEEP
        N''LOGMGR_QUEUE'', -- https://www.sqlskills.com/help/waits/LOGMGR_QUEUE
        N''MEMORY_ALLOCATION_EXT'', -- https://www.sqlskills.com/help/waits/MEMORY_ALLOCATION_EXT
        N''ONDEMAND_TASK_QUEUE'', -- https://www.sqlskills.com/help/waits/ONDEMAND_TASK_QUEUE
        N''PARALLEL_REDO_DRAIN_WORKER'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_DRAIN_WORKER
        N''PARALLEL_REDO_LOG_CACHE'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_LOG_CACHE
        N''PARALLEL_REDO_TRAN_LIST'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_TRAN_LIST
        N''PARALLEL_REDO_WORKER_SYNC'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_SYNC
        N''PARALLEL_REDO_WORKER_WAIT_WORK'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_WAIT_WORK
        N''PREEMPTIVE_OS_FLUSHFILEBUFFERS'', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_OS_FLUSHFILEBUFFERS
        N''PREEMPTIVE_XE_GETTARGETSTATE'', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_XE_GETTARGETSTATE
        N''PVS_PREALLOCATE'', -- https://www.sqlskills.com/help/waits/PVS_PREALLOCATE
        N''PWAIT_ALL_COMPONENTS_INITIALIZED'', -- https://www.sqlskills.com/help/waits/PWAIT_ALL_COMPONENTS_INITIALIZED
        N''PWAIT_DIRECTLOGCONSUMER_GETNEXT'', -- https://www.sqlskills.com/help/waits/PWAIT_DIRECTLOGCONSUMER_GETNEXT
        N''PWAIT_EXTENSIBILITY_CLEANUP_TASK'', -- https://www.sqlskills.com/help/waits/PWAIT_EXTENSIBILITY_CLEANUP_TASK
        N''QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'', -- https://www.sqlskills.com/help/waits/QDS_PERSIST_TASK_MAIN_LOOP_SLEEP
        N''QDS_ASYNC_QUEUE'', -- https://www.sqlskills.com/help/waits/QDS_ASYNC_QUEUE
        N''QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'',
            -- https://www.sqlskills.com/help/waits/QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP
        N''QDS_SHUTDOWN_QUEUE'', -- https://www.sqlskills.com/help/waits/QDS_SHUTDOWN_QUEUE
        N''REDO_THREAD_PENDING_WORK'', -- https://www.sqlskills.com/help/waits/REDO_THREAD_PENDING_WORK
        N''REQUEST_FOR_DEADLOCK_SEARCH'', -- https://www.sqlskills.com/help/waits/REQUEST_FOR_DEADLOCK_SEARCH
        N''RESOURCE_QUEUE'', -- https://www.sqlskills.com/help/waits/RESOURCE_QUEUE
        N''SERVER_IDLE_CHECK'', -- https://www.sqlskills.com/help/waits/SERVER_IDLE_CHECK
        N''SLEEP_BPOOL_FLUSH'', -- https://www.sqlskills.com/help/waits/SLEEP_BPOOL_FLUSH
        N''SLEEP_DBSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_DBSTARTUP
        N''SLEEP_DCOMSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_DCOMSTARTUP
        N''SLEEP_MASTERDBREADY'', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERDBREADY
        N''SLEEP_MASTERMDREADY'', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERMDREADY
        N''SLEEP_MASTERUPGRADED'', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERUPGRADED
        N''SLEEP_MSDBSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_MSDBSTARTUP
        N''SLEEP_SYSTEMTASK'', -- https://www.sqlskills.com/help/waits/SLEEP_SYSTEMTASK
        N''SLEEP_TASK'', -- https://www.sqlskills.com/help/waits/SLEEP_TASK
        N''SLEEP_TEMPDBSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_TEMPDBSTARTUP
        N''SNI_HTTP_ACCEPT'', -- https://www.sqlskills.com/help/waits/SNI_HTTP_ACCEPT
        N''SOS_WORK_DISPATCHER'', -- https://www.sqlskills.com/help/waits/SOS_WORK_DISPATCHER
        N''SP_SERVER_DIAGNOSTICS_SLEEP'', -- https://www.sqlskills.com/help/waits/SP_SERVER_DIAGNOSTICS_SLEEP
        N''SQLTRACE_BUFFER_FLUSH'', -- https://www.sqlskills.com/help/waits/SQLTRACE_BUFFER_FLUSH
        N''SQLTRACE_INCREMENTAL_FLUSH_SLEEP'', -- https://www.sqlskills.com/help/waits/SQLTRACE_INCREMENTAL_FLUSH_SLEEP
        N''SQLTRACE_WAIT_ENTRIES'', -- https://www.sqlskills.com/help/waits/SQLTRACE_WAIT_ENTRIES
        N''VDI_CLIENT_OTHER'', -- https://www.sqlskills.com/help/waits/VDI_CLIENT_OTHER
        N''WAIT_FOR_RESULTS'', -- https://www.sqlskills.com/help/waits/WAIT_FOR_RESULTS
        N''WAITFOR'', -- https://www.sqlskills.com/help/waits/WAITFOR
        N''WAITFOR_TASKSHUTDOWN'', -- https://www.sqlskills.com/help/waits/WAITFOR_TASKSHUTDOWN
        N''WAIT_XTP_RECOVERY'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_RECOVERY
        N''WAIT_XTP_HOST_WAIT'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_HOST_WAIT
        N''WAIT_XTP_OFFLINE_CKPT_NEW_LOG'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_OFFLINE_CKPT_NEW_LOG
        N''WAIT_XTP_CKPT_CLOSE'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_CKPT_CLOSE
        N''XE_DISPATCHER_JOIN'', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_JOIN
        N''XE_DISPATCHER_WAIT'', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_WAIT
        N''XE_TIMER_EVENT'' -- https://www.sqlskills.com/help/waits/XE_TIMER_EVENT
        )
    AND [waiting_tasks_count] > 0
    )
SELECT TOP 10
    MAX ([W1].[wait_type]) AS [WaitType],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S],
    CAST (''https://www.sqlskills.com/help/waits/'' + MAX ([W1].[wait_type]) as XML) AS [Help/Info URL]
INTO #WaitStats
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2] ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 95; -- percentage threshold
GO

--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)
SET @xml = CAST (( SELECT WaitType AS ''td'','''', Resource_S AS ''td'','''', Signal_S AS ''td'','''', Wait_S AS ''td'','''', WaitCount AS ''td'','''',
Percentage AS ''td'','''', AvgWait_S AS ''td'','''', AvgRes_S AS ''td'','''',  AvgSig_S AS ''td'','''', [Help/Info URL] AS ''td'',''''
From #WaitStats
FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

SET @body =''<html><body><H3>SQL Wait Stats</H3>
<table border = 1> 
<tr>
<th> WaitType </th> <th> Resource_S </th> <th> Signal_S </th> <th>  Wait_S </th> <th>  WaitCount </th> <th>  Percentage </th> <th>  AvgWait_S </th>
<th> AvgRes_S </th> <th> AvgSig_S </th> <th> [Help/Info URL] </th>''    


SET @body = @body + @xml +''</table></body></html>''

EXEC msdb.dbo.sp_send_dbmail
@profile_name = ''SQL_DBA_mail'',
@body = @body,
@body_format =''HTML'',
@recipients = ''provide your email address'',
@subject = ''SQL Wait Stats'';
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'twice per week', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=34, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20221019, 
		@active_end_date=99991231, 
		@active_start_time=110000, 
		@active_end_time=235959, 
		@schedule_uid=N'd0d97178-06c7-40c1-a951-e9b23b3b8264'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


