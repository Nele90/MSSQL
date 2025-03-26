USE [DBA_DB]
GO


CREATE PROC [dbo].[UpdateSQLReportBase]
AS

BEGIN

    DECLARE @SQL VARCHAR(MAX)
    SET @SQL = 'IF EXISTS(SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N''' + 'SQLReportBase' + ''') AND type = (N''U'')) DROP TABLE [' + 'SQLReportBase' + ']' 
    --if write EXEC @SQL without parentheses  sql says Error: is not a valid 
    EXEC (@SQL)
END

SELECT 
  C.Name, 
  C.Path, 
  u.UserName,
  C.CreationDate
INTO SQLReportBase
FROM ReportServer..Catalog as c
INNER JOIN ReportServer..Users as u
ON c.CreatedByID = u.UserID
WHERE c.Type = 2
GO
