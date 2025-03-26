USE [msdb]
GO

/****** Object:  Job [DBA: Check DBADAsh Critial events]    Script Date: 02.09.2024 10:35:32 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 02.09.2024 10:35:32 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Check DBADAsh Critial events', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Check DBADAsh critical events in the last 2 hours', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'DBAsa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [rptCheckDBADashCriticalEvent]    Script Date: 02.09.2024 10:35:33 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'rptCheckDBADashCriticalEvent', 
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
/* sma_mssql_rpt_dbadash_crit_events.sql - MSSQL report to simulate */
/*   the DBADash critical events (performance) custom view.         */
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

-- MSSQL instance ID in DBADash repository
DECLARE @sInstanceId INT = 
(
  SELECT 
    InstanceId 
  FROM 
    [DBADashDB].[dbo].[Instances]
  WHERE
    Instance = @sInstanceName
);     

--
-- Define the data range for checked running jobs.
--

-- Start date and time for the previous day
DECLARE @StartDate DATETIME = CONVERT(DATETIME, DATEADD(mi,-120,GETUTCDATE())) ;
-- End date and time for the previous day
DECLARE @EndDate DATETIME = CONVERT(DATETIME, SYSDATETIME()) ;


/********************************************************************/
/* Step 2 - evaluate the average and max CPU load for last two hours*/
/********************************************************************/

DECLARE @dAvgCPU DECIMAL(6,2);
DECLARE @dMaxCPU DECIMAL(6,2); 

SELECT 
  @dAvgCPU = CONVERT(DECIMAL(6,2),SUM(SumSQLProcessCPU*1.0)/SUM(SampleCount*1.0)),
  @dMaxCPU = CONVERT(DECIMAL(6,2),MAX(MaxTotalCPU*1.0))
FROM
  [DBADashDB].[dbo].[CPU]
WHERE
  (InstanceId = @sInstanceId) AND
  (EventTime BETWEEN @StartDate AND @EndDate); 
  



/********************************************************************/
/* Step 3 - evaluate the critical wait (ms/sec) for the last 2 hours*/
/********************************************************************/

DECLARE @CriticalWaitMsPerSec DECIMAL(9,2);
DECLARE @CriticalWaitStatus INT; 
DECLARE @LatchWaitMsPerSec DECIMAL(9,2);
DECLARE @LockWaitMsPerSec DECIMAL(9,2);
DECLARE @IOWaitMsPerSec DECIMAL(9,2);
DECLARE @WaitMsPerSec DECIMAL(9,2);
DECLARE @SignalWaitPct DECIMAL(9,2);


WITH 
 wait1
AS
(
SELECT 
  W.InstanceID,
  W.WaitTypeID,
  SUM(W.wait_time_ms)*1000.0 / MAX(SUM(W.sample_ms_diff*1.0)) OVER(PARTITION BY InstanceID) WaitMsPerSec,
  SUM(W.wait_time_ms) wait_time_ms,
  SUM(W.signal_wait_time_ms) as signal_wait_time_ms
FROM 
  [DBADashDB].[dbo].[Waits] AS W 
WHERE 
  (InstanceId = @sInstanceId) AND 
  (W.SnapshotDate>= CAST(@StartDate AS DATETIME2(2)) AND W.SnapshotDate < CAST(@EndDate AS DATETIME2(2)))
GROUP BY 
  W.InstanceID,W.WaitTypeID
),
wait AS
(
SELECT 
  W.InstanceID,	
  SUM(CASE WHEN WT.IsCriticalWait =1 THEN W.WaitMsPerSec ELSE 0 END) CriticalWaitMsPerSec,  
  SUM(CASE WHEN WT.WaitType LIKE ''LATCH%'' THEN W.WaitMsPerSec  ELSE 0 END) LatchWaitMsPerSec,
  SUM(CASE WHEN WT.WaitType LIKE ''LCK%'' THEN W.WaitMsPerSec  ELSE 0 END) LockWaitMsPerSec,
  SUM(CASE WHEN WT.WaitType LIKE ''PAGEIO%'' OR WT.WaitType LIKE ''WRITE%'' THEN W.WaitMsPerSec  ELSE 0 END) IOWaitMsPerSec,
  SUM(W.WaitMsPerSec) WaitMsPerSec,
  SUM(signal_wait_time_ms)/NULLIF(SUM(wait_time_ms*1.0),0) as SignalWaitPct
FROM 
  wait1 AS w
JOIN 
  [DBADashDB].[dbo].[WaitType] AS WT ON WT.WaitTypeID = W.WaitTypeID
GROUP BY 
  w.InstanceID
)
SELECT
  @CriticalWaitMsPerSec = CONVERT(DECIMAL(9,2),wait.CriticalWaitMsPerSec),
  @CriticalWaitStatus = CASE 
    WHEN wait.CriticalWaitMsPerSec=0 THEN 4 
	WHEN wait.CriticalWaitMsPerSec> thres.CriticalWaitCriticalThreshold THEN 1 
	WHEN wait.CriticalWaitMsPerSec> thres.CriticalWaitWarningThreshold THEN 2 
	ELSE 3 
  END, 
  @LatchWaitMsPerSec=CONVERT(DECIMAL(9,2),wait.LatchWaitMsPerSec),
  @LockWaitMsPerSec=CONVERT(DECIMAL(9,2),wait.LockWaitMsPerSec),
  @IOWaitMsPerSec=CONVERT(DECIMAL(9,2),wait.IOWaitMsPerSec),
  @WaitMsPerSec=CONVERT(DECIMAL(9,2),wait.WaitMsPerSec),
  @SignalWaitPct=CONVERT(DECIMAL(9,2),wait.SignalWaitPct)
FROM
  wait
CROSS JOIN 
  [DBADashDB].[dbo].[PerformanceThresholds] AS thres
;

/********************************************************************/
/* Step 4 - evaluate the IO events for the last 2 hours.            */
/********************************************************************/
DECLARE @ReadIOPs DECIMAL(9,2);
DECLARE @WriteIOPs DECIMAL(9,2);
DECLARE @IOPs DECIMAL(9,2);
DECLARE @ReadMBsec DECIMAL(9,2);
DECLARE @WriteMBsec DECIMAL(9,2);
DECLARE @MBsec DECIMAL(9,2);
DECLARE @ReadLatency DECIMAL(9,2);
DECLARE @ReadLatencyStatus INT;
DECLARE @WriteLatency  DECIMAL(9,2);
DECLARE @WriteLatencyStatus INT;
DECLARE @Latency  DECIMAL(9,2);
DECLARE @MaxReadIOPs  DECIMAL(9,2);
DECLARE @MaxWriteIOPs  DECIMAL(9,2);
DECLARE @MaxIOPs  DECIMAL(9,2);
DECLARE @MaxReadMBsec  DECIMAL(9,2);
DECLARE @MaxWriteMBsec  DECIMAL(9,2);
DECLARE @MaxMBsec  DECIMAL(9,2);


WITH dbio 
AS 
(
 SELECT 
   IOS.InstanceID,
   SUM(IOS.num_of_reads)/(SUM(IOS.sample_ms_diff)/1000.0) AS ReadIOPs,
   SUM(IOS.num_of_writes)/(SUM(IOS.sample_ms_diff)/1000.0) AS WriteIOPs,
   SUM(IOS.num_of_reads+IOS.num_of_writes)/(SUM(IOS.sample_ms_diff)/1000.0) AS IOPs,
   SUM(IOS.num_of_bytes_read)/POWER(1024.0,2)/(SUM(IOS.sample_ms_diff)/1000.0) ReadMBsec,
   SUM(IOS.num_of_bytes_written)/POWER(1024.0,2)/(SUM(IOS.sample_ms_diff)/1000.0) WriteMBsec,
   SUM(IOS.num_of_bytes_read+IOS.num_of_bytes_written)/POWER(1024.0,2)/(SUM(IOS.sample_ms_diff)/1000.0) MBsec,
   SUM(IOS.io_stall_read_ms)/(NULLIF(SUM(IOS.num_of_reads),0)*1.0) AS ReadLatency,
   SUM(IOS.io_stall_write_ms)/(NULLIF(SUM(IOS.num_of_writes),0)*1.0) AS WriteLatency,
   SUM(IOS.io_stall_read_ms+IOS.io_stall_write_ms)/(NULLIF(SUM(IOS.num_of_writes+IOS.num_of_reads),0)*1.0) AS Latency,
   MAX(IOS.MaxReadIOPs) AS MaxReadIOPs,
   MAX(IOS.MaxWriteIOPs) AS MaxWriteIOPs,
   MAX(IOS.MaxIOPs) AS MaxIOPs,
   MAX(IOS.MaxReadMBsec) AS MaxReadMBsec,
   MAX(IOS.MaxWriteMBsec) AS MaxWriteMBsec,
   MAX(IOS.MaxMBsec) AS MaxMBsec
FROM 
  [DBADashDB].[dbo].[DBIOStats] AS IOS
WHERE 
  IOS.DatabaseID=-1 AND 
  IOS.Drive=''*'' AND 
  IOS.FileID=-1 AND 
  IOS.InstanceID = @sInstanceId AND
  (IOS.SnapshotDate>=CAST(@StartDate AS DATETIME2(2)) AND IOS.SnapshotDate<CAST(@EndDate AS DATETIME2(2)))
GROUP BY 
  IOS.InstanceID
)
SELECT
  @ReadIOPs = CONVERT(DECIMAL(9,2),dbio.ReadIOPs),
  @WriteIOPs =CONVERT(DECIMAL(9,2),dbio.WriteIOPs),
  @IOPs=CONVERT(DECIMAL(9,2),dbio.IOPs),
  @ReadMBsec=CONVERT(DECIMAL(9,2),dbio.ReadMBsec),
  @WriteMBsec=CONVERT(DECIMAL(9,2),dbio.WriteMBsec),
  @MBsec=CONVERT(DECIMAL(9,2),dbio.MBsec),
  @ReadLatency=CONVERT(DECIMAL(9,2),dbio.ReadLatency),
  @ReadLatencyStatus=CASE 
    WHEN dbio.ReadIOPs < thres.MinIOPsThreshold THEN 3 
	WHEN dbio.ReadLatency > thres.ReadLatencyCriticalThreshold THEN 1 
	WHEN dbio.ReadLatency > thres.ReadLatencyWarningThreshold THEN 2 
	WHEN dbio.ReadLatency <= thres.ReadLatencyGoodThreshold THEN 4 
	ELSE 3 
  END,
  @WriteLatency=CONVERT(DECIMAL(9,2),dbio.WriteLatency),
  @WriteLatencyStatus=CASE 
    WHEN dbio.WriteIOPs < thres.MinIOPsThreshold THEN 3 
	WHEN dbio.WriteLatency > thres.ReadLatencyCriticalThreshold THEN 1 
	WHEN dbio.WriteLatency > thres.ReadLatencyWarningThreshold THEN 2 
	WHEN dbio.WriteLatency <= thres.ReadLatencyGoodThreshold THEN 4 
	ELSE 3 
  END,
  @Latency=CONVERT(DECIMAL(9,2),dbio.Latency),
  @MaxReadIOPs=CONVERT(DECIMAL(9,2),dbio.MaxReadIOPs),
  @MaxWriteIOPs=CONVERT(DECIMAL(9,2),dbio.MaxWriteIOPs),
  @MaxIOPs=CONVERT(DECIMAL(9,2),dbio.MaxIOPs),
  @MaxReadMBsec=CONVERT(DECIMAL(9,2),dbio.MaxReadMBsec),
  @MaxWriteMBsec=CONVERT(DECIMAL(9,2),dbio.MaxWriteMBsec),
  @MaxMBsec=CONVERT(DECIMAL(9,2),dbio.MaxMBsec)
FROM
  dbio
CROSS JOIN 
  [DBADashDB].[dbo].[PerformanceThresholds] AS thres
;

/********************************************************************/
/* Step 5 - definition of table variable with collected instance    */
/*  critical events.                                                */
/********************************************************************/
-- List of long running jobs
DECLARE @ListCriticalEvents TABLE
(
  instance_name VARCHAR(255),
  event_name  VARCHAR(255),  
  event_value DECIMAL(9,2)
);

/********************************************************************/
/* Step 6 - fill list of collected collected instance''              */
/*  critical events.                                                */
/********************************************************************/

-- Evaluate the MaxCPU critical event
IF (@dMaxCPU>=90.0)
BEGIN
  INSERT INTO  @ListCriticalEvents
  (
   instance_name,
   event_name,
   event_value
  )
  VALUES
  (
    @sInstanceName,
	''Max CPU, %'',
	@dMaxCPU 
  );
END

-- Evaluate the critical wait (ms/sec)
IF (@CriticalWaitStatus=1)
BEGIN
  INSERT INTO  @ListCriticalEvents
  (
   instance_name,
   event_name,
   event_value
  )
  VALUES
  (
    @sInstanceName,
	''Critical Wait, ms/sec'',
	@CriticalWaitStatus  
  );
END

-- Evaluate the critical read latency (ms)
IF (@ReadLatencyStatus=1)
BEGIN
  INSERT INTO  @ListCriticalEvents
  (
   instance_name,
   event_name,
   event_value
  )
  VALUES
  (
    @sInstanceName,
	 ''Read Latency, ms'',
	 @ReadLatency  
  );
END

-- Evaluate the critical write latency (ms)
IF (@WriteLatencyStatus=1)
BEGIN
  INSERT INTO  @ListCriticalEvents
  (
   instance_name,
   event_name,
   event_value
  )
  VALUES
  (
    @sInstanceName,
	 ''Write Latency, ms'',
	 @WriteLatency
  );
END

/********************************************************************/
/* Step 7 - if we have rows in the list of the critical event, we   */
/* should send the report via e-mail.                               */
/* Otherwise just quit the script.                                   */
/********************************************************************/

-- Check ammount of rows in a list with missing log backups 
-- in a hour.
DECLARE @iRowsInReport INT; 
SELECT @iRowsInReport = COUNT(*) FROM @ListCriticalEvents;

IF (@iRowsInReport=0)
BEGIN
  PRINT CONCAT(''There are no citical events on '', @sInstanceName, ''instance'')
  PRINT CONCAT(
    ''in the last 2 hours between '', 
    CONVERT(NVARCHAR(25),@StartDate,104),
    '' and '',
    CONVERT(NVARCHAR(25),@EndtDate,104)
    )  
  GOTO Quit
END;


/********************************************************************/
/* Step 8 - preparing parameters for msdb.dbo.sp_send_dbmail stored */
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
  @sEmailSubject=CONCAT(
   ''Critical events in the last 2 hours between '' ,
     CONVERT(NVARCHAR(25),@StartDate,104),
    '' and '',
    CONVERT(NVARCHAR(25),@EndtDate,104)
    ) 
;

-- HTML data variable with critical event
DECLARE @sHtmlData NVARCHAR(MAX); 

 SELECT  
   @sHtmlData = COALESCE(@sHtmlData + '' '', '''') + 
 CAST(
 ''<tr  style="id''+CAST(((ROW_NUMBER() OVER(ORDER BY db.event_name ASC) %3) +1) AS NVARCHAR(3))+''">'' +
   ''<td>'' + db.db.event_name  + ''</td>'' +   
   ''<td>'' + CAST(db.event_value AS NVARCHAR(15)) + ''</td>'' + 
  ''</tr>''  
 AS NVARCHAR(MAX)  )
 FROM 
  @ListCriticalEvents AS db;

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
    <th>EVENT_NAME</th>
    <th>EVENT_VALUE</th>    
   </tr> 
   @TABLE_DATA@ 
  </table>
</body>
</html>
''
AS NVARCHAR(MAX)) ; 

/********************************************************************/
/* Step 9 - filling HTML body with title, table caption and         */ 
/*  rows data.                                                      */ 
/********************************************************************/
-- Document tiitle
SET @sHtmlBody=REPLACE(@sHtmlBody,''@TITLE@'',@sEmailSubject);
-- Documnent heading
SET @sHtmlBody=REPLACE(@sHtmlBody,''@BODY_TITLE@'',@sEmailSubject);
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
/* Step 10 - sending report to recipients via e-mail.                */ 
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
/* Step 11 - if requested, provide debug output of variables values. */
/********************************************************************/

IF (@iDebugEnabled = 1)
BEGIN
SELECT
  @sInstanceName AS "InstanceName",
  @sInstanceId AS "InstanceId",
  @StartDate AS "From",
  @EndDate AS "To",
  @dAvgCPU AS "CPU AVerage",
  @dMaxCPU AS "CPU MAX",
  @CriticalWaitMsPerSec AS "CriticalWaitMsPerSec",
  @CriticalWaitStatus  AS "CriticalWaitStatus",   
  @LatchWaitMsPerSec AS "LatchWaitMsPerSec",
  @LockWaitMsPerSec AS "LockWaitMsPerSec",
  @IOWaitMsPerSec AS "IOWaitMsPerSec",
  @WaitMsPerSec AS "WaitMsPerSec",
  @SignalWaitPct AS "SignalWaitPct",
  @ReadIOPs AS "ReadIOPs",
  @WriteIOPs AS "WriteIOPs",
  @IOPs AS "IOPs",
  @ReadMBsec AS "ReadMBsec",
  @WriteMBsec AS "WriteMBsec",
  @MBsec AS "MBsec",
  @ReadLatency AS "ReadLatency",
  @ReadLatencyStatus AS "ReadLatencyStatus",     
  @WriteLatency AS "WriteLatency",
  @WriteLatencyStatus AS  "WriteLatencyStatus",    
  @Latency AS "Latency",
  @MaxReadIOPs AS "MaxReadIOPs",
  @MaxWriteIOPs AS "MaxWriteIOPs",
  @MaxIOPs AS "MaxIOPs",
  @MaxReadMBsec AS "MaxReadMBsec",
  @MaxWriteMBsec AS "MaxWriteMBsec",
  @MaxMBsec AS "MaxMBsec"
;
END



/********************************************************************/
/* Step 999 - exiting script.                                       */
/********************************************************************/
GOTO Quit

Quit:
GO  ', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DBADashCritcalEventsEvery2 Hours', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240902, 
		@active_end_date=99991231, 
		@active_start_time=110000, 
		@active_end_time=235959, 
		@schedule_uid=N'f22871f8-542d-4770-857d-3e8fb1e1b094'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


