USE [DBA_DB]
GO

CREATE PROC [dbo].[UpdateSQLAlertsBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLAlertsBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLAlertsBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

SELECT name, enabled
INTO SQLAlertsBase
FROM msdb..sysalerts 
GO

