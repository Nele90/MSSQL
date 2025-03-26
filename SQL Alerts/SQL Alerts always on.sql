-- Add important SQL Agent Alerts to your instance

-- This will work with SQL Server 2008 and newer
-- Glenn Berry

-- https://glennsqlperformance.com/
-- Twitter: GlennAlanBerry

-- Listen to my Pluralsight courses
-- https://www.pluralsight.com/author/glenn-berry

-- Change the @OperatorName as needed


USE [msdb];
GO

SET NOCOUNT ON;


-- Change @OperatorName as needed
DECLARE @OperatorName sysname = N'DBA_member';

-- Change @CategoryName as needed
DECLARE @CategoryName sysname = N'SQL Server Agent Alerts';

-- Make sure you have an Agent Operator defined that matches the name you supplied
IF NOT EXISTS(SELECT * FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
	BEGIN
		RAISERROR ('There is no SQL Operator with a name of %s' , 18 , 16 , @OperatorName);
		RETURN;
	END

-- Add Alert Category if it does not exist
IF NOT EXISTS (SELECT *
               FROM msdb.dbo.syscategories
               WHERE category_class = 2  -- ALERT
			   AND category_type = 3
               AND name = @CategoryName)
	BEGIN
		EXEC dbo.sp_add_category @class = N'ALERT', @type = N'NONE', @name = @CategoryName;
	END

-- Get the server name
DECLARE @ServerName sysname = (SELECT @@SERVERNAME);


-- Alert Names start with the name of the server 
DECLARE @Error1480AlertName sysname = @ServerName + N' Alert - Error 1480: SQL Server has detected avalability group change role';
DECLARE @Error19407AlertName sysname = @ServerName + N' Alert - Error 19407: SQL Server has detected avalability group Lease timeout';
DECLARE @Error19421AlertName sysname = @ServerName + N' Alert - Error 19421: SQL Server has detected avalability group Lease timeout_1';


--Error 1480: SQL Server has detected avalability group change role
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error1480AlertName)
EXEC msdb.dbo.sp_add_alert @name=@Error1480AlertName, 
		@message_id=1480, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1,
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'


IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error1480AlertName)
	BEGIN
			EXEC msdb.dbo.sp_add_notification @alert_name= @Error1480AlertName, @operator_name= @OperatorName, @notification_method = 1
	END



-- Error 19407: SQL Server has detected avalability group Lease timeout
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error19407AlertName)
EXEC msdb.dbo.sp_add_alert @name=@Error19407AlertName, 
		@message_id=19407, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error19407AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error19407AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 20 Error: Fatal Error in Current Process
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error19421AlertName)
		EXEC msdb.dbo.sp_add_alert @name=@Error19421AlertName, 
		@message_id=19421, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=0, 
		@category_name=N'[Uncategorized]', 
		@job_id=N'00000000-0000-0000-0000-000000000000'


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error19421AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error19421AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END