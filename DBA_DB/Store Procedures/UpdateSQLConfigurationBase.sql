USE [DBA_DB]
GO

CREATE PROC [dbo].[UpdateSQLConfigurationBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLConfigurationBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLConfigurationBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

SELECT *
INTO SQLConfigurationBase
from sys.configurations
GO;
GO


