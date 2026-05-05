USE master
GO
DECLARE @Time_Start DATETIME;
DECLARE @Time_End DATETIME;
SET @Time_Start = getdate() - 2;
SET @Time_End = getdate();
-- Create the temporary table
CREATE TABLE #ErrorLog (
	logdate DATETIME
	,processinfo VARCHAR(MAX)
	,Message VARCHAR(MAX)
	)
-- Populate the temporary tablesys
INSERT #ErrorLog (
	logdate
	,processinfo
	,Message
	)
EXEC master.dbo.xp_readerrorlog 0
	,1
	,NULL
	,NULL
	,@Time_Start
	,@Time_End
	,N'desc';
-- Filter the temporary table
SELECT LogDate
	,Message
FROM #ErrorLog
WHERE (
		Message LIKE '%error%'
		OR Message LIKE '%failed%'
		)
	AND processinfo NOT LIKE 'logon'
	AND (Message NOT LIKE 'DBCC CHECKDB%found 0 errors%')
	AND (Message NOT LIKE 'CHECKDB for database%finished without errors%')
	AND (Message NOT LIKE 'The error log has been reinitialized.%')
	AND (Message NOT LIKE 'Logging SQL Server messages in file%')
	AND (Message NOT LIKE 'The client was unable to reuse a session with SPID%')
	AND (Message NOT LIKE 'Error: 18056, Severity: 20, State%')
ORDER BY logdate DESC
-- Drop the temporary table 
DROP TABLE #ErrorLog
