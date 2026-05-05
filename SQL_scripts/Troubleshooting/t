USE master
GO

declare @Time_Start datetime;
declare @Time_End datetime;
set @Time_Start=getdate()-2;
set @Time_End=getdate();
-- Create the temporary table

IF(Object_ID('tempdb..#ErrorLog')) IS NOT NULL
	DROP TABLE #ErrorLog
CREATE TABLE #ErrorLog ([ErrorLogText] [varchar] (256) NULL ,
						[ContinuationRow] [bit] NULL)

IF(Object_ID('tempdb..#ServerHistory')) IS NOT NULL
	DROP TABLE #ServerHistory						
CREATE TABLE #ServerHistory (
						[ErrorLogText] [varchar] (256) NULL ,
						[EventDate] [datetime] NOT NULL)
						
-- Populate the temporary table
INSERT #ErrorLog ([ErrorLogText], [ContinuationRow])
   EXEC master.dbo.xp_readerrorlog;
   
   
INSERT INTO #ServerHistory
(ErrorLogText, EventDate)
SELECT 
	SUBSTRING(ErrorLogText,34,256),
	CONVERT(datetime, SUBSTRING(ErrorLogText,1,22), 120)
FROM #ErrorLog
WHERE	ErrorLogText IS NOT NULL 
			AND (ErrorLogText LIKE '%error%' OR ErrorLogText LIKE '%failed%')
			AND (ErrorLogText NOT LIKE '%Logging SQL Server messages in file%')
			AND (ErrorLogText NOT LIKE '%Login failed for user%')
			AND (ErrorLogText NOT LIKE '%DBCC CHECKDB%found 0 errors%')

SELECT * FROM #ServerHistory  
WHERE EventDate BETWEEN @Time_Start AND @Time_End

-- Drop the temporary table 
DROP TABLE #ErrorLog
DROP TABLE #ServerHistory
