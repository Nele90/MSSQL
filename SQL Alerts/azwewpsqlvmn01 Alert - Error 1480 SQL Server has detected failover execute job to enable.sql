USE [msdb]
GO

/****** Object:  Alert [azwewpsqlvmn01 Alert - Error 1480: SQL Server has detected failover execute job to enable/disable SSRS jobs]    Script Date: 21.06.2024 15:34:08 ******/
EXEC msdb.dbo.sp_add_alert @name=N'azwewpsqlvmn01 Alert - Error 1480: SQL Server has detected failover execute job to enable/disable SSRS jobs', 
		@message_id=1480, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=0, 
		@database_name=N'ourdatas', 
		@category_name=N'[Uncategorized]', 
		@job_name=N'DBA: Enable SSRS Jobs on Failover'
GO


