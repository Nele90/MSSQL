USE [msdb]
GO

/****** Object:  Job [DBA: Check Long Running Jobs]    Script Date: 11.08.2024 20:20:29 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 11.08.2024 20:20:30 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Check Long Running Jobs', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Report regarding long running jobs during latest day', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check if the SQL Job duration in unusal during latest day]    Script Date: 11.08.2024 20:20:31 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check if the SQL Job duration in unusal during latest day', 
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
/* sma_mssql_rpt_long_running_jobs.sql - MSSQL query what reports   */
/*   long running jobs for the last day.                            */
/*                                                                  */
/********************************************************************/


SET NOCOUNT ON;

/********************************************************************/
/* Step 1 - variables declaration.                                  */ 
/********************************************************************/ 
-- Flag for conditional execution
-- 1 - TRUE
-- 0 - FALSE
DECLARE @iDebugEnabled TINYINT = 1;

-- Current MSSQL instance name
DECLARE @sInstanceName VARCHAR(255) = CAST(SERVERPROPERTY(''ServerName'') AS VARCHAR(255));

--
-- Define the data range for checked running jobs.
--

-- Start date and time for the previous day
DECLARE @StartDate DATETIME = CONVERT(DATE, GETDATE() - 1) ;
-- End date and time for the previous day
DECLARE @EndDate DATETIME = CONVERT(DATE, GETDATE()) ;

-- List of long running jobs
DECLARE @ListLongRunningJobs TABLE
(
  instance_name VARCHAR(255),
  job_name  VARCHAR(255),
  -- Date the job or step started execution, in yyyyMMdd format
  job_run_date INT,
  -- Time the job or step started in HHmmss format
  job_run_time INT,
  job_run_duration_in_sec INT 
);


/********************************************************************/
/* Step 2 - variables initialization.                               */ 
/********************************************************************/ 

-- List of long running jobs
INSERT INTO 
  @ListLongRunningJobs
(
  instance_name,
  job_name,
  job_run_date,
  job_run_time,
  job_run_duration_in_sec 
)
SELECT
  @sInstanceName AS instance_name,
  dt.job_name,
  MAX(dt.job_run_date)  AS job_run_date,
  MAX(dt.job_run_time)  AS job_run_time,
  AVG(dt.job_run_duration_in_sec) AS job_run_duration_in_sec
FROM
(
  SELECT 
    j.name AS job_name, 
    run_date AS job_run_date, 
    run_time AS job_run_time,
    (run_duration/10000*3600 + run_duration/100%100*60 + run_duration%100) AS job_run_duration_in_sec
  FROM 
     msdb.dbo.sysjobhistory h
  INNER JOIN 
    msdb.dbo.sysjobs j ON h.job_id = j.job_id
  WHERE 
    -- Successfully completed jobs
    h.run_status = 1 AND 
    -- Filter for jobs completed on or after the start date/time
    run_date >= CONVERT(VARCHAR(8), @StartDate, 112) AND 
    -- Filter for jobs completed before the end date/time
    run_date < CONVERT(VARCHAR(8), @EndDate, 112) AND 
    -- Duration greater than the job''s "Notify Level Email"
    (run_duration/10000*3600 + run_duration/100%100*60 + run_duration%100) > j.notify_level_email
) AS dt
GROUP BY 
  dt.job_name
;    

/********************************************************************/
/* Step 3 - if we have rows in the long running jobs report,  we    */
/* should send the report via e-mail.                               */
/* Otherwise just quit the script.                                   */
/********************************************************************/

-- Check ammount of rows in a list with missing log backups 
-- in a hour.
DECLARE @iRowsInReport INT; 
SELECT @iRowsInReport = COUNT(*) FROM @ListLongRunningJobs;

IF (@iRowsInReport=0)
BEGIN
  PRINT ''There are no long running jobs in the report.''
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
''Long running jobs for the last day'' 
;

-- HTML data variable with long running jobs
DECLARE @sHtmlData NVARCHAR(MAX); 

 SELECT  
   @sHtmlData = COALESCE(@sHtmlData + '' '', '''') + 
 CAST(
 ''<tr  style="id''+CAST(((ROW_NUMBER() OVER(ORDER BY db.job_run_duration_in_sec DESC) %3) +1) AS NVARCHAR(3))+''">'' +
   ''<td>'' + db.job_name + ''</td>'' +
   ''<td>'' + db.instance_name + ''</td>'' +
   -- job_run_date in format DD.MM.YYYY
   ''<td>'' + 
      CONVERT(
         NVARCHAR(25), 
         DATEFROMPARTS
         ( 
           -- Years 
           db.job_run_date / 10000,
           -- Months
           db.job_run_date % 10000 / 100, 
           -- Days
           db.job_run_date % 100
         )  , 
         104
      ) + 
   ''</td>'' +
   -- Job run time in format hh:mi:ss:mmm
   ''<td>'' + 
      CONVERT(
         NVARCHAR(25), 
         TIMEFROMPARTS
         ( 
           -- Hour 
           db.job_run_time  / 10000,
           -- Minutes
           db.job_run_time % 10000 / 100, 
           -- Seconds
           db.job_run_time % 100,
           -- Fractions
           5,
           -- Precision
           1
         )  , 
         114
      ) + 
   ''</td>'' +
   ''<td>'' + CAST(db.job_run_duration_in_sec AS NVARCHAR(10)) + ''</td>'' + 
  ''</tr>''  
 AS NVARCHAR(MAX)  )
 FROM 
   @ListLongRunningJobs AS db;


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
    <th>job_name</th>
    <th>instance_name</th>
    <th>job_run_date</th>
    <th>job_run_time</th>
    <th>job_run_duration_in_sec</th>
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
SET @sHtmlBody=REPLACE(@sHtmlBody,''@TITLE@'',''SMA issues with MSSQL jobs''
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
-- EOF - sma_mssql_rpt_long_running_jobs.sq
', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Night one-time run', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240811, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'496b381e-97d1-422c-9706-adb2ffe3d5ac'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

