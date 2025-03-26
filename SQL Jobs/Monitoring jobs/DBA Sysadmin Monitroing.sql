USE [msdb]
GO

/****** Object:  Job [DBA: Sysadmin Monitoring]    Script Date: 19.02.2024 11:18:00 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 19.02.2024 11:18:00 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Sysadmin Monitoring', 
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
/****** Object:  Step [Check for new sysadmin logins]    Script Date: 19.02.2024 11:18:01 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check for new sysadmin logins', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--check if table exists, if not table will be created
IF OBJECT_ID(N''dbo.SysadminBase'', N''U'') IS NOT NULL
BEGIN
    PRINT ''Table Exists''
END
ELSE 
BEGIN
	USE [DBA_DB]
	CREATE TABLE [dbo].[SysadminBase](
		[login] [sysname] NOT NULL,
		[status] [varchar](8) NOT NULL,
		[type] [nvarchar](60) NULL,
		[create_date] [datetime] NOT NULL,
		[modify_date] [datetime] NOT NULL
	) ON [PRIMARY]
--fill base table
	INSERT INTO Sysadminbase (login, status, type, create_date, modify_date)
		select mp.name as login,
			   case when mp.is_disabled = 1 then ''Disabled''
					else ''Enabled''
					end as status,
			  mp.type_desc as type, mp.create_date, mp.modify_date
		from sys.server_role_members srp 
		join sys.server_principals mp 
			 on mp.principal_id = srp.member_principal_id
		join sys.server_principals rp 
			 on rp.principal_id = srp.role_principal_id
		where rp.name = ''sysadmin'' and mp.name NOT LIKE ''NT%'' and mp.is_disabled = 0
		order by status DESC
END


--create temp table to compare with base
select mp.name as login,
       case when mp.is_disabled = 1 then ''Disabled''
            else ''Enabled''
            end as status,
      mp.type_desc as type, mp.create_date, mp.modify_date
INTO #SysadminBase
from sys.server_role_members srp 
join sys.server_principals mp 
     on mp.principal_id = srp.member_principal_id
join sys.server_principals rp 
     on rp.principal_id = srp.role_principal_id
where rp.name = ''sysadmin'' and mp.name NOT LIKE ''NT%'' and mp.is_disabled = 0
order by status DESC

--insert into base table new sysadmin
IF (SELECT COUNT(*) FROM #SysadminBase) > (SELECT COUNT(*) FROM SysadminBase)
 BEGIN 
--Send email 
	DECLARE @xml NVARCHAR(MAX)
	DECLARE @body NVARCHAR(MAX) 

	SET @xml = CAST (( SELECT [login] AS ''td'','''', [status] AS ''td'','''', [type] AS ''td'','''', CONVERT(varchar,create_date,21) ''td'',''''	, CONVERT(varchar,modify_date,21) ''td'',''''					
	From #SysadminBase
	WHERE create_date > DATEADD(HOUR, -2, GETDATE())
	FOR XML PATH(''tr''), Elements ) AS NVARCHAR(MAX))

	SET @body =''<html><body><H3>New Sysadmin Login</H3>
	<table border = 1> 
	<tr>
	<th> login </th> <th> status </th> <th> type </th> <th> create_date </th>  <th> modify_date </th>''    


	SET @body = @body + @xml +''</table></body></html>''

	EXEC msdb.dbo.sp_send_dbmail
	@profile_name = ''SQL_DBA_mail'',
	@body = @body,
	@body_format =''HTML'',
	@recipients = ''provide your email address'',
	@subject = ''New Sysadmin Logins'';

	INSERT INTO Sysadminbase (login, status, type, create_date, modify_date)
	SELECT login, status, type, create_date, modify_date
	FROM #SysadminBase WHERE create_date > DATEADD(HOUR, -2, GETDATE())

    DROP TABLE #SysadminBase
END
ELSE 
BEGIN
	DROP TABLE #SysadminBase
END
', 
		@database_name=N'DBA_DB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every Hour', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240219, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'f1cc0af3-ad8e-4493-90f0-625a2b6b1e8d'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


