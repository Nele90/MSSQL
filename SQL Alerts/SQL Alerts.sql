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
DECLARE @Sev19AlertName sysname = @ServerName + N' Alert - Sev 19 Error: Fatal Error in Resource';
DECLARE @Sev20AlertName sysname = @ServerName + N' Alert - Sev 20 Error: Fatal Error in Current Process';
DECLARE @Sev21AlertName sysname = @ServerName + N' Alert - Sev 21 Error: Fatal Error in Database Process';
DECLARE @Sev22AlertName sysname = @ServerName + N' Alert - Sev 22 Error: Fatal Error: Table Integrity Suspect';
DECLARE @Sev23AlertName sysname = @ServerName + N' Alert - Sev 23 Error: Fatal Error Database Integrity Suspect';
DECLARE @Sev24AlertName sysname = @ServerName + N' Alert - Sev 24 Error: Fatal Hardware Error';
DECLARE @Sev25AlertName sysname = @ServerName + N' Alert - Sev 25 Error: Fatal Error';
DECLARE @Error823AlertName sysname = @ServerName + N' Alert - Error 823: The operating system returned an error';
DECLARE @Error824AlertName sysname = @ServerName + N' Alert - Error 824: Logical consistency-based I/O error';
DECLARE @Error825AlertName sysname = @ServerName + N' Alert - Error 825: Read-Retry Required';
DECLARE @Error832AlertName sysname = @ServerName + N' Alert - Error 832: Constant page has changed';
DECLARE @Error855AlertName sysname = @ServerName + N' Alert - Error 855: Uncorrectable hardware memory corruption detected';
DECLARE @Error856AlertName sysname = @ServerName + N' Alert - Error 856: SQL Server has detected hardware memory corruption, but has recovered the page';
DECLARE @Error35217AlertName sysname = @ServerName + N' Alert - Error 35217: SQL Server has detected Max Worker Threads';
DECLARE @Error17810AlertName sysname = @ServerName + N' Alert - Error 17810: URGENT POTENTIAL ATTACK';
DECLARE @Error17832AlertName sysname = @ServerName + N' Alert - Error 17832: URGENT POTENTIAL ATTACK';
DECLARE @Error17836AlertName sysname = @ServerName + N' Alert - Error 17836: URGENT POTENTIAL ATTACK';
DECLARE @Error18204AlertName sysname = @ServerName + N' Alert - Error 18204: Backup Failure';
DECLARE @Error18210AlertName sysname = @ServerName + N' Alert - Error 18210: Backup Failure';
DECLARE @Error3009AlertName sysname = @ServerName + N' Alert - Error 3009: Backup Failure';
DECLARE @Error3017AlertName sysname = @ServerName + N' Alert - Error 3017: Backup Failure';
DECLARE @Error3033AlertName sysname = @ServerName + N' Alert - Error 3033: Backup Failure';
DECLARE @Error3201AlertName sysname = @ServerName + N' Alert - Error 3201: Backup Failure';
DECLARE @Error18267AlertName sysname = @ServerName + N' Alert - Error 18267: Restore Success';
DECLARE @Error18268AlertName sysname = @ServerName + N' Alert - Error 18268: Restore Success';
DECLARE @Error18269AlertName sysname = @ServerName + N' Alert - Error 18269: Restore Success';
DECLARE @Error3142AlertName sysname = @ServerName + N' Alert - Error 3142: Restore Failure';
DECLARE @Error3145AlertName sysname = @ServerName + N' Alert - Error 3145: Restore Failure';
DECLARE @Error3441AlertName sysname = @ServerName + N' Alert - Error 3441: Restore Failure';
DECLARE @Error3443AlertName sysname = @ServerName + N' Alert - Error 3443: Restore Failure';
DECLARE @Error1205AlertName sysname = @ServerName + N'Alert - Error 1205 - Transaction Deadlock';
DECLARE @Error17883AlertName sysname = @ServerName + N'Alert - Error 17883 - Non-Yielding Worker Process';
DECLARE @Error17890AlertName sysname = @ServerName + N'Alert - Error 17890 - Most SQL process memory paged out';
DECLARE @Error833AlertName sysname = @ServerName + N'Alert - Error 833 - Slow IO';


--Error 17883 - Non-Yielding Worker Process
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error17883AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error17883AlertName, 
				  @message_id = 17883, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error17883AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error17883AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
----------------

--Error 1205 - Transaction Deadlock
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error1205AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error1205AlertName, 
				  @message_id = 1205, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error17883AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error1205AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

	----------------

--Error 17890 - Most SQL process memory paged out
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error17890AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error17890AlertName, 
				  @message_id = 17890, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error17883AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error17890AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

		----------------

--Error 833 - Slow IO
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error833AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error833AlertName, 
				  @message_id = 833, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error17883AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error833AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


--Error 18204: Backup Failure
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error18204AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error18204AlertName, 
				  @message_id = 18204, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error18204AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error18204AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	


--Error 18210: Backup Failure
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error18210AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error18210AlertName, 
				  @message_id = 18210, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error18210AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error18210AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Error 3009: Backup Failure
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3009AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3009AlertName, 
				  @message_id = 3009, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3009AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3009AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Error 3017: Backup Failure
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3017AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3017AlertName, 
				  @message_id = 3017, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3017AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3017AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Error 3033: Backup Failure
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3033AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3033AlertName, 
				  @message_id = 3033, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3033AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3033AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Error 3201: Backup Failure
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3201AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3201AlertName, 
				  @message_id = 3201, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3201AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3201AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Restore Success - 18267
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error18267AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error18267AlertName, 
				  @message_id = 18267, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error18267AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error18267AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Restore Success - 18268
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error18268AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error18268AlertName, 
				  @message_id = 18268, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error18268AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error18268AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
--Restore Success - 18269
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error18269AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error18269AlertName, 
				  @message_id = 18269, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error18269AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error18269AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Restore Failure - 3142
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3142AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3142AlertName, 
				  @message_id = 3142, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3142AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3142AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
--Restore Failure - 3145
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3145AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3145AlertName, 
				  @message_id = 3145, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3145AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3145AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
	
--Restore Failure - 3441
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3441AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3441AlertName, 
				  @message_id = 3441, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3441AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3441AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	

	
--Restore Failure - 3443
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error3443AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error3443AlertName, 
				  @message_id = 3443, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error3443AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error3443AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

- Sev 17832 URGENT POTENTIAL ATTACK
 EXEC msdb.dbo.sp_add_alert @name=@Error17832AlertName, 
		@message_id=17832, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=@CategoryName

-- Sev 17832 URGENT POTENTIAL ATTACK
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error17832AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error17832AlertName, 
				  @message_id = 0, @severity = 19, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error17832AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error17832AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 17836 URGENT POTENTIAL ATTACK
 EXEC msdb.dbo.sp_add_alert @name=@Error17836AlertName, 
		@message_id=17836, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@category_name=@CategoryName

-- Sev 17836 URGENT POTENTIAL ATTACK
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error17836AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error17836AlertName, 
				  @message_id = 0, @severity = 19, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
			  FROM dbo.sysalerts AS sa
			  INNER JOIN dbo.sysnotifications AS sn
			  ON sa.id = sn.alert_id
			  WHERE sa.name = @Error17836AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error17836AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

-- Sev 17810 URGENT POTENTIAL ATTACK
 EXEC msdb.dbo.sp_add_alert @name=@Error17810AlertName, 
        @message_id=17810, 
        @enabled=1, 
        @delay_between_responses=0, 
        @include_event_description_in=1, 
        @category_name=@CategoryName

-- Sev 17810 URGENT POTENTIAL ATTACK
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error17810AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error17810AlertName, 
				  @message_id = 0, @severity = 19, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error17810AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error17810AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END



--Error 35217: SQL Server has detected Max Worker Threads
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error35217AlertName)
EXEC msdb.dbo.sp_update_alert @name= @Error35217AlertName, 
		@message_id=35217, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@database_name=N'', 
		@notification_message=N'', 
		@event_description_keyword=N'', 
		@performance_condition=N'', 
		@wmi_namespace=N'', 
		@wmi_query=N'', 
		@job_id=N'00000000-0000-0000-0000-000000000000'
GO
EXEC msdb.dbo.sp_add_notification @alert_name= @Error35217AlertName, @operator_name= @OperatorName, @notification_method = 1
GO

-- Sev 19 Error: Fatal Error in Resource
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev19AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev19AlertName, 
				  @message_id = 0, @severity = 19, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev19AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev19AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 20 Error: Fatal Error in Current Process
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev20AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev20AlertName, 
				  @message_id = 0, @severity = 20, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000'

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev20AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev20AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 21 Error: Fatal Error in Database Process
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev21AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev21AlertName, 
				  @message_id = 0, @severity = 21, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev21AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev21AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 22 Error: Fatal Error Table Integrity Suspect
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev22AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev22AlertName, 
				  @message_id = 0, @severity = 22, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev22AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev22AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 23 Error: Fatal Error Database Integrity Suspect
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev23AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev23AlertName, 
				  @message_id = 0, @severity = 23, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev23AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev23AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 24 Error: Fatal Hardware Error
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev24AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev24AlertName, 
				  @message_id = 0, @severity = 24, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev24AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev24AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 25 Error: Fatal Error
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev25AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev25AlertName, 
				  @message_id = 0, @severity = 25, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName,
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev25AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev25AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

-- Error 823 Alert added on 8/11/2014

-- Error 823: Operating System Error
-- How to troubleshoot a Msg 823 error in SQL Server	
-- http://support.microsoft.com/kb/2015755
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error823AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error823AlertName, 
				  @message_id = 823, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error823AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error823AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
-- Error 824 Alert added on 8/11/2014

-- Error 824: Logical consistency-based I/O error
-- How to troubleshoot Msg 824 in SQL Server
-- http://support.microsoft.com/kb/2015756
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error824AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error824AlertName, 
				  @message_id = 824, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error824AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error824AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Error 825: Read-Retry Required
-- How to troubleshoot Msg 825 (read retry) in SQL Server
-- http://support.microsoft.com/kb/2015757
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error825AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error825AlertName, 
				  @message_id = 825, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  =N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error825AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error825AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

-- Error 832 Alert added on 10/30/2013

-- Error 832: Constant page has changed
-- http://www.sqlskills.com/blogs/paul/dont-confuse-error-823-and-error-832/
-- http://support.microsoft.com/kb/2015759
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error832AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error832AlertName, 
				  @message_id = 832, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error832AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error832AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Memory Error Correction alerts added on 10/30/2013

-- Mitigation of RAM Hardware Errors	 		
-- When SQL Server 2012 Enterprise Edition is installed on a Windows 2012 operating system with hardware that supports bad memory diagnostics, 
-- you will notice new error messages like 854, 855, and 856 instead of the 832 errors that LazyWriter usually generates.
-- Error 854 is just informing you that your instance supports memory error correction

-- Using SQL Server in Windows 8 and Windows Server 2012 environments
-- http://support.microsoft.com/kb/2681562


-- Check for SQL Server 2012 or greater and Enterprise Edition
-- You also need Windows Server 2012 or greater, plus hardware that supports memory error correction
IF LEFT(CONVERT(CHAR(2),SERVERPROPERTY('ProductVersion')), 2) >= '11' AND SERVERPROPERTY('EngineEdition') = 3
    BEGIN
        -- Error 855: Uncorrectable hardware memory corruption detected
		IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error855AlertName)
			EXEC msdb.dbo.sp_add_alert @name = @Error855AlertName, 
						  @message_id = 855, @severity = 0, @enabled = 1, 
						  @delay_between_responses = 900, @include_event_description_in = 1, 
						  @category_name = @CategoryName, 
						  @job_id  = N'00000000-0000-0000-0000-000000000000';


		-- Add a notification if it does not exist
		IF NOT EXISTS(SELECT *
					  FROM dbo.sysalerts AS sa
					  INNER JOIN dbo.sysnotifications AS sn
					  ON sa.id = sn.alert_id
					  WHERE sa.name = @Error855AlertName)
			BEGIN
				EXEC msdb.dbo.sp_add_notification @alert_name = @Error855AlertName, @operator_name = @OperatorName, @notification_method = 1;
			END

		-- Error 856: SQL Server has detected hardware memory corruption, but has recovered the page
		IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error856AlertName)
			EXEC msdb.dbo.sp_add_alert @name = @Error856AlertName, 
						  @message_id = 856, @severity = 0, @enabled = 1, 
						  @delay_between_responses = 900, @include_event_description_in = 1, 
						  @category_name = @CategoryName, 
						  @job_id  = N'00000000-0000-0000-0000-000000000000';


		-- Add a notification if it does not exist
		IF NOT EXISTS(SELECT *
					  FROM dbo.sysalerts AS sa
					  INNER JOIN dbo.sysnotifications AS sn
					  ON sa.id = sn.alert_id
					  WHERE sa.name = @Error856AlertName)
			BEGIN
				EXEC msdb.dbo.sp_add_notification @alert_name = @Error856AlertName, @operator_name = @OperatorName, @notification_method = 1;
			END
    END
GO





