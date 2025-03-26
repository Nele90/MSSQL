CREATE   PROCEDURE [dbo].[GetFailedLoginsStats]
(@LastHours int = 0 , @SinceLogDate datetime2 = NULL)
AS

IF (@LastHours > 0)
BEGIN
 Set @SinceLogDate = DATEADD(HOUR,-@LastHours,SYSDATETIME())
END
print @SinceLogDate

   DECLARE @ErrorLogCount INT
   DECLARE @LastLogDate DATETIME
   DECLARE @ErrorLogInfo TABLE (
       LogDate DATETIME
      ,ProcessInfo NVARCHAR (50)
      ,[Text] NVARCHAR (MAX)
      )
   DECLARE @EnumErrorLogs TABLE (
       [Archive#] INT
      ,[Date] DATETIME
      ,LogFileSizeMB INT
      )
   INSERT INTO @EnumErrorLogs
   EXEC sp_enumerrorlogs
   SELECT @ErrorLogCount = MIN([Archive#]), @LastLogDate = MAX([Date])
   FROM @EnumErrorLogs
   WHILE @ErrorLogCount IS NOT NULL
   BEGIN
      INSERT INTO @ErrorLogInfo
      EXEC sp_readerrorlog @ErrorLogCount
      SELECT @ErrorLogCount = MIN([Archive#]), @LastLogDate = MAX([Date])
      FROM @EnumErrorLogs
      WHERE [Archive#] > @ErrorLogCount
      AND @LastLogDate > getdate() - 7
   END
   -- List all last week failed logins count of attempts and the Login failure message
   ;with errInfo as(
   SELECT COUNT (TEXT) AS NumberOfAttempts, TEXT AS Details, MIN(LogDate) as MinLogDate, MAX(LogDate) as MaxLogDate
   FROM @ErrorLogInfo
   WHERE ProcessInfo = 'Logon'
      AND TEXT LIKE '%fail%'
      AND LogDate >= @SinceLogDate 
   GROUP BY TEXT
	)   
   
   Select *  , RIGHT(Details,len(Details)+1-CHARINDEX('[',Details)) CLIENT, @@SERVERNAME as SQLServerName
   from errInfo
   ORDER BY NumberOfAttempts DESC

GO