USE [DBA_DB]
GO

CREATE PROC [dbo].[UpdateSQLDatabaseBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLDatabaseBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLDatabaseBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

SELECT name, state_desc
INTO SQLDatabaseBase
from sys.databases 
GO;
GO


