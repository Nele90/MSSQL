USE [msdb]
GO

/****** Object:  Job [DBA: Check Missing Full Back-up]    Script Date: 08.04.2024 17:51:09 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 08.04.2024 17:51:09 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Check Missing Full Back-up', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'MSSQL job for sending e-mail if there is  no backup for 2 weeks.', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check full backup status within past two weeks]    Script Date: 08.04.2024 17:51:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check full backup status within past two weeks', 
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
/* sma_mssql_chk_bkps.sql - MSSQL job for sending e-mail if there is*/
/*  no backup for 2 weeks.                                          */
/********************************************************************/
SET NOCOUNT ON;

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

-- Is the current instance the AlwaysOn configuration?
-- 0 - not AlwaysOn
-- 1 - AkwaysOn
DECLARE @iIsAlwaysOn SMALLINT;

-- Defining date ramge variables for backup checking
DECLARE @dtNow DATETIME;
DECLARE @dtFrom DATETIME;
DECLARE @dtTo DATETIME;

-- List databases missing a log back-up in a hour
DECLARE @ListMissingBackups TABLE
(
  database_name SYSNAME,
  instance_name VARCHAR(255),
  database_last_backup DATETIME,
  backup_age_in_days INT

);

-- List of databases
DECLARE @ListOnlineDbs TABLE
(
  database_name SYSNAME,
  PRIMARY KEY CLUSTERED (database_name)
);  

-- Ammount of rows in a list with missing log backups in a hour
DECLARE @iRowsMissingBackups INT;

/********************************************************************/
/* Step 2 - variables initialization.                               */ 
/********************************************************************/ 
-- Current MSSQL instance name
SET @sInstanceName = CAST(SERVERPROPERTY(''ServerName'') AS VARCHAR(255));
-- Is the current instance the AlwaysOn configuration?
-- 0 - not AlwaysOn
-- 1 - AkwaysOn
SET @iIsAlwaysOn = CAST(SERVERPROPERTY(''IsHadrEnabled'') AS SMALLINT);
-- Defining date ramge variables for backup checking
SET @dtNow = GETDATE();
SET @dtFrom = @dtNow;
SET @dtTo = DATEADD(week,-2,@dtFrom);

-- Get list databases.
INSERT INTO @ListOnlineDbs
(
  database_name
)
SELECT
  wlist_dbs.database_name
FROM
(
SELECT 
  CASE @iIsAlwaysOn
  -- AlwaysOn configuration
  WHEN 1 
    -- Check if database is preferred for backups on ALwaysON configuration
    THEN CASE master.sys.fn_hadr_backup_is_preferred_replica(dbs.name)
	    WHEN 1 THEN ''TRUE''
	    ELSE ''FALSE''
	  END -- END CASE
  -- Not AlwaysON configuration. 
  -- Thre is only one instance here.
  -- Database is definitely used for backups on current instance
  ELSE ''TRUE'' 
  END AS is_preferred_for_backup,
  dbs.name AS database_name,
  @sInstanceName AS instance_name
FROM 
  master.sys.databases AS dbs
WHERE 
  (UPPER(dbs.name) NOT IN (''TEMPDB'',''MASTER'',''MODEL'',''MSDB'',''DBA_DB''))  AND
  (dbs.recovery_model_desc=''FULL'')
) AS wlist_dbs
WHERE
  wlist_dbs.is_preferred_for_backup=''TRUE''
;

-- Databases missing a Full Back-Up within past two weeks. 
INSERT INTO @ListMissingBackups 
(
  database_name,
  instance_name,
  database_last_backup,
  backup_age_in_days

)
-- Looking for databases with backup history
SELECT 
  CAST(bkps.database_name AS SYSNAME) AS database_name, 
  @sInstanceName AS instance_name, 
  MAX(bkps.backup_finish_date) AS database_last_backup, 
  CAST(DATEDIFF(day, MAX(bkps.backup_finish_date), @dtFrom ) AS INT) AS backup_age_in_days
FROM
  msdb.dbo.backupset AS bkps
INNER JOIN
  @ListOnlineDbs AS dbs
ON
 bkps.database_name=dbs.database_name
WHERE
  bkps.type = ''D''  
GROUP BY 
  bkps.database_name 
HAVING      
  (MAX(bkps.backup_finish_date) < @dtTo)
UNION
-- Looking for databases without backup history  
SELECT      
  dbs.name AS database_name,  
  @sInstanceName AS instance_name,
  @dtTo  AS database_last_backup,  
  CAST(DATEDIFF(day, @dtTo, @dtFrom ) AS INT) AS backup_age_in_days
FROM 
   master.dbo.sysdatabases AS dbs 
LEFT JOIN 
  msdb.dbo.backupset AS bkps 
ON 
  dbs.name  = bkps.database_name 
WHERE 
  (bkps.database_name IS NULL ) AND 
  (UPPER(dbs.name) NOT IN (''TEMPDB'',''MASTER'',''MODEL'',''MSDB'',''DBA_DB'')) 
;

-- Check ammount of rows in a list with missing backups 
-- within past two weeks.
SELECT @iRowsMissingBackups = COUNT(*) FROM @ListMissingBackups;

/********************************************************************/
/* Step 3 - if we have a missing backups within past two weeks,     */   
/*   we should send a report via e-mail.exiting script.             */
/* Otherwise just quit job.                                         */
/********************************************************************/
IF (@iRowsMissingBackups=0)
BEGIN
  PRINT ''There are no missed full backups within two weeks''
  GOTO Quit
END;

/********************************************************************/
/* Step 4 - preparing parameters for msdb.dbo.sp_send_dbmail stored */
/*   procedure to send HTML report.                                 */
/********************************************************************/
-- List of e-mail addresses
DECLARE @sEmailRecipients VARCHAR(266);
-- E-mail subject
DECLARE @sEmailSubject VARCHAR(255);

SELECT  
  @sEmailRecipients=CASE @iDebugEnabled
  WHEN 1 THEN
   ''''  + '';''
  WHEN 0 THEN
   ''''  + '';'' +
   ''provide your email address''   + '';'' +
   ''''  + '';''
  END,
  @sEmailSubject=
''Missing full database back-up within past two weeks''
;

-- HTML data variable with missed database backups
DECLARE @sHtmlData NVARCHAR(MAX); 

 SELECT  
   @sHtmlData = COALESCE(@sHtmlData + '' '', '''') + 
 CAST(
 ''<tr  style="id''+CAST(((ROW_NUMBER() OVER(ORDER BY db.backup_age_in_days DESC) %3) +1) AS NVARCHAR(3))+''">'' +
   ''<td>'' + db.database_name + ''</td>'' +
   ''<td>'' + db.instance_name + ''</td>'' +
   ''<td>'' + CONVERT(NVARCHAR(40),db.database_last_backup,113) + ''</td>'' +
   ''<td>'' + CAST(db.backup_age_in_days AS NVARCHAR(10)) + ''</td>'' + 
  ''</tr>''  
 AS NVARCHAR(MAX)  )
 FROM 
  @ListMissingBackups AS db;



-- HTML body variable
DECLARE @sHtmlBody NVARCHAR(MAX);
SELECT @sHtmlBody=CAST(
''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <style>
      #id0 {	background-color: rgb(200, 240, 200);	}      
      #id1 {	background-color: rgb(240, 200, 200);	}      
      #id2 {	background-color: rgb(200, 200, 240);	}
        
      table, tr, th, td {
            border:1px solid black;
            border-collapse:collapse;
            text-align:lef;
      }
     
      Caption {
        font-weight:bold; 
        background-color:yellow;       
     }        
    </style>
    <title>@TITLE@</title>
</head>
<body>
  <h3>@BODY_TITLE@</h3> 
  <table>
    <caption>@CAPTION@</caption>
   <tr>
    <th>DATABASE_NAME</th>
    <th>INSTANCE_NAME</th>
    <th>LAST_BACKUP_DATE</th>
    <th>BACKUP_AGE_IN_DAYS</th>
   </tr> 
   @TABLE_DATA@ 
  </table>
</body>
</html>
''
AS NVARCHAR(MAX)) ;

/********************************************************************/
/* Step 5 - filling HTML body with title, table caption and         */ 
/*  rows data.                                                      */ 
/********************************************************************/
-- Document tiitle
SET @sHtmlBody=REPLACE(@sHtmlBody,''@TITLE@'',''SMA Backup issues''
);
-- Documnent heading
SET @sHtmlBody=REPLACE(@sHtmlBody,''@BODY_TITLE@'',@sEmailSubject
);
-- Table caption with MSSQL instance name
SET @sHtmlBody=REPLACE(
     @sHtmlBody,
     ''@CAPTION@'',
     ''MSSQL instance: '' + @sInstanceName
);
-- Adding table data to HTML body     
SET @sHtmlBody=REPLACE(
     @sHtmlBody,
    ''@TABLE_DATA@'',
    @sHtmlData
);


/********************************************************************/
/* Step 6 - sending report to recipients via e-mail.                */ 
/*  rows data.                                                      */ 
/********************************************************************/
EXEC msdb.dbo.sp_send_dbmail
  @profile_name = ''SQL_DBA_mail'',
  @recipients=@sEmailRecipients,
  @subject=@sEmailSubject,
  @body=@sHtmlBody,
  @body_format = ''HTML''    
;  

/********************************************************************/
/* Step 9 - exiting script.                                         */
/********************************************************************/
GOTO Quit

Quit:
GO
-- EOF - sma_mssql_chk_bkps.sql', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily Full Backup Check', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240311, 
		@active_end_date=99991231, 
		@active_start_time=20000, 
		@active_end_time=235959, 
		@schedule_uid=N'f6151180-e893-4fb1-99b2-d341147af725'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
