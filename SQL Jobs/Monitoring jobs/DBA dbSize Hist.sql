USE [msdb]
GO

/****** Object:  Job [DBA: dbSize Historical Data]    Script Date: 25.06.2024 10:59:36 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 25.06.2024 10:59:36 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: dbSize Historical Data', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Colecting databases size historical data', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [job_dbSize_hist]    Script Date: 25.06.2024 10:59:37 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'job_dbSize_hist', 
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
/* sma_mssql_dbsize_hist.sql - MSSQL code to collect databases size */
/*   info into fact table.                                          */
/*                                                                  */
/* Notes:                                                           */
/* DBA_DB.dbo.job_DBSize_HistData - fact table name with collected  */
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
DECLARE @sInstanceName NVARCHAR(255);
SET @sInstanceName = CAST(SERVERPROPERTY(''ServerName'') AS NVARCHAR(255));

-- Fact schema name
DECLARE @sDBFactTable SYSNAME;
DECLARE @sSchemaFactTable SYSNAME;
DECLARE @sNameFactTable SYSNAME;
SELECT 
  @sDBFactTable = ''DBA_DB'',
  @sSchemaFactTable = ''dbo'',
  @sNameFactTable = ''job_DBSize_HistData'';


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
    DROP TABLE [DBA_DB].[dbo].[job_DBSize_HistData];
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
CREATE TABLE [DBA_DB].[dbo].[job_DBSize_HistData]
(
    Id INT IDENTITY(1, 1) NOT NULL,
    InsertedAt DATETIME NOT NULL,
    dbName SYSNAME NOT NULL,
    InstanceName NVARCHAR(255) NOT NULL,
    TotalSizeGB DECIMAL(18,5) NOT NULL,
    DataSizeGB DECIMAL(18,5) NOT NULL,
    LogSizeGB DECIMAL(18,5) NOT NULL,
    CONSTRAINT PK_job_DBSize_HistData PRIMARY KEY CLUSTERED (Id, InsertedAt,dbName)    
    
);
END

/********************************************************************/
/* Step 4 - define variable with current date and time for          */
/*  data inserting into fact table.                                 */ 
/********************************************************************/ 
DECLARE @dtNow DATETIME;
SET @dtNow = GETDATE();

/********************************************************************/
/* Step 5 - inserting the historical data into the fact table.      */
/********************************************************************/ 
INSERT INTO [DBA_DB].[dbo].[job_DBSize_HistData]
( 
  InsertedAt, 
  dbName,
  InstanceName,
  TotalSizeGB,
  DataSizeGB,
  LogSizeGB       
)
SELECT
   @dtNow,
   d.name,
   @sInstanceName, 
   CAST(t.total_size/1024 AS DECIMAL(18,5)),
   CAST(t.data_size/1024 AS DECIMAL(18,5)), 
   CAST(t.log_size/1024 AS DECIMAL(18,5)) 
FROM 
(
  SELECT
     database_id,
     log_size = CAST(SUM(CASE WHEN [type] = 1 THEN size END) * 8. / 1024 AS DECIMAL(18,5)),
     data_size = CAST(SUM(CASE WHEN [type] = 0 THEN size END) * 8. / 1024 AS DECIMAL(18,5)),
     total_size = CAST(SUM(size) * 8. / 1024 AS DECIMAL(18,5))
  FROM 
    sys.master_files
  GROUP BY 
    database_id
) t
JOIN sys.databases d ON d.database_id = t.database_id
;
/********************************************************************/
/* Step 9 - exiting script.                                         */
/********************************************************************/
GOTO Quit

Quit:
GO
-- EOF - sma_mssql_dbsize_hist.sql', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dailyDbSizeHistory', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240625, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'99f34de2-6a1b-42bb-af94-49f6d4646721'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


