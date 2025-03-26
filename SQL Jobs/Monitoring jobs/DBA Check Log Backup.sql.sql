/********************************************************************/
/* sma_mssql_chk_blog03.sql - MSSQL job for sending e-mail          */
/*  if there is no log backup in 1 hour.                            */
/*                                                                  */
/* 14 July 2024 - change request, backup database log               */
/*                only if createt database older than 1 day.        */
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
  backup_age_in_hours INT

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
SET @sInstanceName = CAST(SERVERPROPERTY('ServerName') AS VARCHAR(255));
-- Is the current instance the AlwaysOn configuration?
-- 0 - not AlwaysOn
-- 1 - AkwaysOn
SET @iIsAlwaysOn = CAST(SERVERPROPERTY('IsHadrEnabled') AS SMALLINT);
-- Defining date ramge variables for backup checking
SET @dtNow = GETDATE();
SET @dtFrom = @dtNow;
SET @dtTo = DATEADD(hour,-1,@dtFrom);


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
	    WHEN 1 THEN 'TRUE'
	    ELSE 'FALSE'
	  END -- END CASE
  -- Not AlwaysON configuration. 
  -- Thre is only one instance here.
  -- Database is definitely used for backups on current instance
  ELSE 'TRUE' 
  END AS is_preferred_for_backup,
  dbs.name AS database_name,
  @sInstanceName AS instance_name
FROM 
  master.sys.databases AS dbs
WHERE 
  -- 1. Skip databases younger than 1 day
  (CAST(DATEDIFF(day, dbs.create_date, @dtNow) AS INT)>1) AND
  -- 2. Skip system databases
  (UPPER(dbs.name) NOT IN ('TEMPDB','MASTER','MODEL','MSDB','DBA_DB'))  AND
  -- 3. Log backup makes sense only for databases in full recovery mode
  (dbs.recovery_model_desc='FULL') 
) AS wlist_dbs
WHERE
  wlist_dbs.is_preferred_for_backup='TRUE'
;

-- Databases with missing log Back-Up in a hour. 
INSERT INTO @ListMissingBackups 
(
  database_name,
  instance_name,
  database_last_backup,
  backup_age_in_hours

)
-- Looking for databases with backup history
SELECT 
  CAST(bkps.database_name AS SYSNAME) AS database_name, 
  @sInstanceName AS instance_name, 
  MAX(bkps.backup_finish_date) AS database_last_backup, 
  CAST(DATEDIFF(hour, MAX(bkps.backup_finish_date), @dtFrom ) AS INT) AS backup_age_in_hours
FROM
  msdb.dbo.backupset AS bkps
INNER JOIN
  @ListOnlineDbs AS dbs
ON
 bkps.database_name=dbs.database_name
WHERE
  (bkps.recovery_model='FULL') AND
  (bkps.type = 'L')  
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
  CAST(DATEDIFF(hour, @dtTo, @dtFrom ) AS INT) AS backup_age_in_hours
FROM 
   master.sys.databases AS dbs 
LEFT JOIN 
  msdb.dbo.backupset AS bkps 
ON 
  dbs.name  = bkps.database_name 
WHERE 
  -- 1. Skip databases younger than 1 day
  (CAST(DATEDIFF(day, dbs.create_date, @dtNow) AS INT)>1) AND
  (bkps.database_name IS NULL ) AND 
  -- 2. Skip system databases
  (UPPER(dbs.name) NOT IN ('TEMPDB','MASTER','MODEL','MSDB','DBA_DB')) AND
    -- 3. Log backup makes sense only for databases in full recovery mode
  (dbs.recovery_model_desc='FULL') 
;

/********************************************************************/
/* Step 3 - if we have a missing log backups in a hour,             */   
/*   we should send a report via e-mail.                            */
/* Otherwise just quit job.                                         */
/********************************************************************/

-- Check ammount of rows in a list with missing log backups 
-- in a hour.
SELECT @iRowsMissingBackups = COUNT(*) FROM @ListMissingBackups;

IF (@iRowsMissingBackups=0)
BEGIN
  PRINT 'There are no missed log backups in a hour'
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
   ''  + ';'
  WHEN 0 THEN
   ''  + ';' +
   'provide your email address'   + ';' +
   ''  + ';'
  END,
  @sEmailSubject=
'Missing log back-up in a hour'
;


-- HTML data variable with missed log backups
DECLARE @sHtmlData NVARCHAR(MAX); 

 SELECT  
   @sHtmlData = COALESCE(@sHtmlData + ' ', '') + 
 CAST(
 '<tr  style="id'+CAST(((ROW_NUMBER() OVER(ORDER BY db.backup_age_in_hours DESC) %3) +1) AS NVARCHAR(3))+'">' +
   '<td>' + db.database_name + '</td>' +
   '<td>' + db.instance_name + '</td>' +
   '<td>' + CONVERT(NVARCHAR(40),db.database_last_backup,113) + '</td>' +
   '<td>' + CAST(db.backup_age_in_hours AS NVARCHAR(10)) + '</td>' + 
  '</tr>'  
 AS NVARCHAR(MAX)  )
 FROM 
  @ListMissingBackups AS db;



-- HTML body variable
DECLARE @sHtmlBody NVARCHAR(MAX);
SELECT @sHtmlBody=CAST(
'
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
    <th>BACKUP_AGE_IN_HOURS</th>
   </tr> 
   @TABLE_DATA@ 
  </table>
</body>
</html>
'
AS NVARCHAR(MAX)) ;

/********************************************************************/
/* Step 5 - filling HTML body with title, table caption and         */ 
/*  rows data.                                                      */ 
/********************************************************************/
-- Document tiitle
SET @sHtmlBody=REPLACE(@sHtmlBody,'@TITLE@','SMA log backup issues'
);
-- Documnent heading
SET @sHtmlBody=REPLACE(@sHtmlBody,'@BODY_TITLE@',@sEmailSubject
);
-- Table caption with MSSQL instance name
SET @sHtmlBody=REPLACE(
     @sHtmlBody,
     '@CAPTION@',
     'MSSQL instance: ' + @sInstanceName
);
-- Adding table data to HTML body     
SET @sHtmlBody=REPLACE(
     @sHtmlBody,
    '@TABLE_DATA@',
    @sHtmlData
);


/********************************************************************/
/* Step 6 - sending report to recipients via e-mail.                */ 
/*  rows data.                                                      */ 
/********************************************************************/
EXEC msdb.dbo.sp_send_dbmail
  @profile_name = 'SQL_DBA_mail',
  @recipients=@sEmailRecipients,
  @subject=@sEmailSubject,
  @body=@sHtmlBody,
  @body_format = 'HTML'    
;  

/********************************************************************/
/* Step 9 - exiting script.                                         */
/********************************************************************/
GOTO Quit

Quit:
GO
-- EOF - sma_mssql_chk_blog03.sql
