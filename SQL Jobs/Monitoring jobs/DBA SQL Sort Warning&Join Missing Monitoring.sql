USE [msdb]
GO

/****** Object:  Job [DBA: SQL Sort Warning&Join Missing Monitoring]    Script Date: 09.04.2024 09:58:36 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 09.04.2024 09:58:37 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Sort Warning&Join Missing Monitoring', 
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
/****** Object:  Step [check for missing join or sort warning]    Script Date: 09.04.2024 09:58:38 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'check for missing join or sort warning', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'INSERT INTO [dbo].[WarningsDefaulTrace] ([TextData], [BinaryData], [DatabaseID], [TransactionID], [LineNumber], [NTUserName], [NTDomainName], [HostName], [ClientProcessID], [ApplicationName], [LoginName], [SPID], [Duration], [StartTime], [EndTime], [Reads], [Writes], [CPU], [Permissions], [Severity], [EventSubClass], [ObjectID], [Success], [IndexID], [IntegerData], [ServerName], [EventClass], [ObjectType], [NestLevel], [State], [Error], [Mode], [Handle], [ObjectName], [DatabaseName], [FileName], [OwnerName], [RoleName], [TargetUserName], [DBUserName], [LoginSid], [TargetLoginName], [TargetLoginSid], [ColumnPermissions], [LinkedServerName], [ProviderName], [MethodName], [RowCounts], [RequestID], [XactSequence], [EventSequence], [BigintData1], [BigintData2], [GUID], [IntegerData2], [ObjectID2], [Type], [OwnerID], [ParentName], [IsSystem], [Offset], [SourceDatabaseID], [SqlHandle], [SessionLoginName], [PlanHandle], [GroupID], [category_id], [name], [trace_column_id], [subclass_name], [subclass_value])
SELECT TextData,	BinaryData,	DatabaseID	,TransactionID	,LineNumber,	NTUserName,	NTDomainName	,HostName	,ClientProcessID,	ApplicationName,	LoginName,	SPID	,Duration	,StartTime	,EndTime	,Reads	,Writes	
,CPU	,Permissions	,Severity	,EventSubClass	,ObjectID	,Success	,IndexID	,IntegerData	,ServerName	,EventClass	,ObjectType	,NestLevel	,State	,Error	,Mode	,Handle	,ObjectName	,DatabaseName	,FileName
,OwnerName	,RoleName	,TargetUserName	,DBUserName	,LoginSid	,TargetLoginName	,TargetLoginSid	,ColumnPermissions	,LinkedServerName	,ProviderName	,MethodName	,RowCounts	,RequestID	,XactSequence	,EventSequence	,
BigintData1	,BigintData2	,[GUID]	,IntegerData2	,ObjectID2	,[Type]	,OwnerID	,ParentName	,IsSystem	,Offset	,SourceDatabaseID	,SqlHandle	,SessionLoginName	,PlanHandle	,GroupID,category_id	,
[name],trace_column_id,subclass_name	,subclass_value
FROM    sys.fn_trace_gettable(CONVERT(VARCHAR(150), ( SELECT TOP 1
                                                              f.[value]
                                                      FROM    sys.fn_trace_getinfo(NULL) f
                                                      WHERE   f.property = 2
                                                    )), DEFAULT) T
        JOIN sys.trace_events TE ON T.EventClass = TE.trace_event_id
        JOIN sys.trace_subclass_values v ON v.trace_event_id = TE.trace_event_id
                                            AND v.subclass_value = t.EventSubClass
WHERE name IN (''Missing Join Predicate'',''Sort Warnings'',''Hash Warning'') and StartTime > DATEADD(HOUR, -1, GETDATE())
ORDER BY StartTime DESC', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240409, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'654a6c8c-b4f9-4901-8d1c-c32b079121f8'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


