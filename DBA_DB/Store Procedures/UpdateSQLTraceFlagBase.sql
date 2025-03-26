USE [DBA_DB]
GO

CREATE PROC [dbo].[UpdateSQLTraceFlagBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLTraceFlagBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLTraceFlagBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

CREATE TABLE SQLTraceFlagBase(
        TraceFlag NVARCHAR(40)
,       Status TINYINT
,       GLOBAL TINYINT
,       SESSION TINYINT
);

INSERT INTO SQLTraceFlagBase 
	EXEC('dbcc tracestatus')
GO
