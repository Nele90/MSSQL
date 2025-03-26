USE [msdb]
GO

/****** Object:  Job [DBA: SQL Login Last Usage]    Script Date: 27.03.2024 13:20:02 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 27.03.2024 13:20:02 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: SQL Login Last Usage', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Monitor Login last time access', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Record logins last time usage]    Script Date: 27.03.2024 13:20:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Record logins last time usage', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/********************************************************************/
/* sma_mssql_login_last_usg.sql - MSSQL code to collect last login  */
/*   access time and insert it into fact table.                     */
/*                                                                  */
/* Notes:                                                           */
/* DBA_DB.dbo.job_Info_LoginLastUsg - fact table name with collected*/
/*   information.                                                   */    
/********************************************************************/
SET NOCOUNT ON
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/********************************************************************/
/* Step 1 - variables declaration.                                  */ 
/********************************************************************/ 
-- Flag for conditional execution
-- 1 - TRUE
-- 0 - FALSE
DECLARE @iDebugEnabled TINYINT;
SET @iDebugEnabled = 0;

-- Current MSSQL instance name
DECLARE @sInstanceName VARCHAR(255);
SET @sInstanceName = CAST(SERVERPROPERTY(''ServerName'') AS VARCHAR(255));

-- Fact schema name
DECLARE @sDBFactTable SYSNAME;
DECLARE @sSchemaFactTable SYSNAME;
DECLARE @sNameFactTable SYSNAME;
SELECT 
  @sDBFactTable = ''DBA_DB'',
  @sSchemaFactTable = ''dbo'',
  @sNameFactTable = ''job_Info_LoginLastUsg'';

/********************************************************************/
/* Step 2 - we should drop fact table in debug mode first.          */ 
/********************************************************************/ 
IF (@iDebugEnabled = 1)
BEGIN
  IF EXISTS
  (
    SELECT * FROM [DBA_DB].INFORMATION_SCHEMA.TABLES 
    WHERE 
      (TABLE_NAME = @sNameFactTable) AND 
      (TABLE_SCHEMA = @sSchemaFactTable)
  )
  BEGIN
    DROP TABLE [DBA_DB].[dbo].[job_Info_LoginLastUsg];
  END  
END



/********************************************************************/
/* Step 3 - create fact table if it does not exist.                 */ 
/********************************************************************/ 
IF NOT EXISTS
  (
    SELECT * FROM [DBA_DB].INFORMATION_SCHEMA.TABLES 
    WHERE 
      (TABLE_NAME = @sNameFactTable) AND 
      (TABLE_SCHEMA = @sSchemaFactTable)
  )
BEGIN  
CREATE TABLE [DBA_DB].[dbo].[job_Info_LoginLastUsg]
(
    Id INT IDENTITY(1, 1) NOT NULL,
    InsertedAt DATETIME NOT NULL,
    LoginName SYSNAME NOT NULL,
    LastAccessDate DATETIME NOT NULL,
    CONSTRAINT PK_job_Info_LoginLastUsg PRIMARY KEY CLUSTERED (Id, InsertedAt)    
    
);
END

/********************************************************************/
/* Step 4 - define variable with current date and time for          */
/*  data inserting into fact table.                                 */ 
/********************************************************************/ 
DECLARE @dtNow DATETIME;
SET @dtNow = GETDATE();

/********************************************************************/
/* Step 5 - inserting the logins last usage into the fact table.    */
/********************************************************************/ 
INSERT INTO [DBA_DB].[dbo].[job_Info_LoginLastUsg]
( 
  InsertedAt, 
  LoginName,
  LastAccessDate     
)
SELECT 
  @dtNow AS "INSERTED_AT",
  sess.login_name AS "LOGIN_NAME", 
  CAST(max(sess.login_time) AS DATETIME) AS "LAST_LOGGED_IN" 
FROM 
  master.sys.dm_exec_sessions AS sess
WHERE 
  sess.login_name NOT LIKE N''NT%'' 
GROUP BY 
  sess.login_name
;  



/********************************************************************/
/* Step 9 - exiting script.                                         */
/********************************************************************/
GOTO Quit

Quit:
GO
-- EOF - sma_mssql_login_last_usg.sql', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly fill table with login last usage time', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240327, 
		@active_end_date=99991231, 
		@active_start_time=2000, 
		@active_end_time=232059, 
		@schedule_uid=N'b0f9f687-9a54-4d97-92a9-72b2587ff44f'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
