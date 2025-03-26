USE [DBA_DB]
GO

/****** Object:  StoredProcedure [dbo].[UpdateSQLJobsBase]    Script Date: 01.03.2024 15:31:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[UpdateSQLJobsBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLJobsBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLJobsBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

SELECT name, enabled 
INTO SQLJobsBase
from msdb..sysjobs 
GO;
GO


