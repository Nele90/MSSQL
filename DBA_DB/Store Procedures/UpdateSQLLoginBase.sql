USE [DBA_DB]
GO
CREATE PROC [dbo].[UpdateSQLLoginBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLLoginStatusBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLLoginStatusBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

SELECT name, is_disabled 
INTO SQLLoginStatusBase
FROM sys.server_principals
ORDER BY name
GO


