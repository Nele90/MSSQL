USE [msdb]
GO

/****** Object:  Job [DBA: Enable SSRS Jobs on Failover]    Script Date: 21.06.2024 15:33:24 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [SQL DBA Monitoring]    Script Date: 21.06.2024 15:33:24 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'SQL DBA Monitoring' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'SQL DBA Monitoring'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Enable SSRS Jobs on Failover', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'SQL DBA Monitoring', 
		@owner_login_name=N'DBAsa', 
		@notify_email_operator_name=N'DBA_member', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [If_Primary_Enable_SSRS_Jobs]    Script Date: 21.06.2024 15:33:26 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'If_Primary_Enable_SSRS_Jobs', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @role VARCHAR(10)
DECLARE @availability_mode int

SET @role = (	select role_desc 
		from 
		sys.dm_hadr_availability_replica_cluster_states rcs
		INNER JOIN sys.dm_hadr_availability_replica_states ars ON rcs.replica_id = ars.replica_id
		WHERE replica_server_name = @@SERVERNAME
	     )

 SET @availability_mode = (	
 
 SELECT availability_mode FROM sys.availability_replicas WHERE replica_server_name = @@SERVERNAME
	    )

IF @role = ''PRIMARY''
		BEGIN
		exec msdb..sp_update_job @job_name = ''073C5DC7-B09D-4964-8FFA-617AD0E0C994'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''273B4933-BD8E-4244-A75C-55C2A950F051'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''2866B830-8C78-4F05-AE2A-DD86696D9A77'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''2A8A2C6F-B3AB-41C5-9914-6F38B235536C'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''2D9169F4-BD06-4A11-BBEA-09AF979494E7'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''2E6173C6-65F2-4E03-A2A2-C274772273D8'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''39491FDC-79E6-41FF-B0D7-34826138C264'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''3C93F78F-813F-45E5-8A92-C194208207EF'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''42239B9C-783B-4447-BAD5-3A3A1F17E199'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''45657978-69E6-4A07-AD72-5FD48B616279'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''4577D411-0EC4-47C7-9DDF-8B4975E564B2'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''4755119E-BCF5-47D8-B20D-80DE63C97595'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''4781BD6F-3A14-4BE6-ADC4-83D58D949C0E'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''4A527B20-4DA2-4640-971B-2B16E07A94F2'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''4E0E2DD1-0892-40CA-BF05-67AA666A1A8A'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''57507F15-1C67-45A9-AA24-F759549DCDD0'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''5E6FAEDE-741C-41B0-B4DF-18C735B779F9'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''6A525555-B62A-404F-8D36-04B5152F279D'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''6B663BBD-AF82-4563-A29F-D5C9E9617766'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''6C1FAC80-B478-4B1A-A3A4-90026D87B3A7'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''6DE27F00-CF80-472B-A63B-4B0B076FFB3E'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''6F653ED0-2757-488E-B653-BBACCD6F5DEA'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''79902D97-C5B4-4AD6-BEE7-57480CFA274D'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''8DD1F9C5-CAF8-4B39-86CE-1B08E8E752B4'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''91FBF8FA-80C5-4C57-A667-7B11D7FE1D65'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''94B6F2C3-46A6-4ABA-8E4C-DEA99AEDF865'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''954CF155-F277-4ECC-96B8-580B9E40F53C'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''96CA3862-A11E-4C69-967F-11026B74A939'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''99224BB3-7EA1-4BC2-A0E7-41173D1D5F7C'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''9933B268-0477-417F-B008-33E1F246E393'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''9BEB94AD-08C1-428C-90B9-C998264E7B70'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''9D9635E2-FB07-4BB9-A97F-E41507EAEDB8'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''9FC7578E-E6E0-4B57-B653-1EC055988280'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''A611DA37-3A9D-4A62-8348-7DC1A3A9EE3A'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''ADB275E7-712B-4687-91F8-8D836A34A7D3'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''B35BFEE7-F6F0-45CE-97EC-5A3171CBC334'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''B9578C50-8A52-4894-8156-2D16D908320B'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''BFB6D8BD-4B7B-4F50-98ED-CFD0095E17FA'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''C2DE3C69-9E00-4E21-8EFD-EC7B98452255'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''C432368B-862C-427A-ACED-63A005280EA0'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''CB387615-1744-4288-B246-D55CC85D3E7E'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''CD6D8923-9471-4354-BAFD-67EACDBF2C59'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''D1A0E7E8-FD6F-4C3D-865E-AB7559A362AC'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''F0CB81C2-8AB1-45C8-BF06-E9F635CC489C'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''F2B4CA25-B7A3-4D73-9734-8748E8D73AC0'', @enabled = 1
		exec msdb..sp_update_job @job_name = ''FA77CFC8-5F45-4E1D-BF7E-3C1EB99DFBD8'', @enabled = 1


END
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IF_secondary_Disable_SSRS_Jobs]    Script Date: 21.06.2024 15:33:26 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IF_secondary_Disable_SSRS_Jobs', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @role VARCHAR(10)
DECLARE @availability_mode int

SET @role = (	select role_desc 
		from 
		sys.dm_hadr_availability_replica_cluster_states rcs
		INNER JOIN sys.dm_hadr_availability_replica_states ars ON rcs.replica_id = ars.replica_id
		WHERE replica_server_name = @@SERVERNAME
	     )

 SET @availability_mode = (	
 
 SELECT availability_mode FROM sys.availability_replicas WHERE replica_server_name = @@SERVERNAME
	    )

IF @role = ''SECONDARY''
		BEGIN
		exec msdb..sp_update_job @job_name = ''073C5DC7-B09D-4964-8FFA-617AD0E0C994'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''273B4933-BD8E-4244-A75C-55C2A950F051'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''2866B830-8C78-4F05-AE2A-DD86696D9A77'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''2A8A2C6F-B3AB-41C5-9914-6F38B235536C'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''2D9169F4-BD06-4A11-BBEA-09AF979494E7'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''2E6173C6-65F2-4E03-A2A2-C274772273D8'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''39491FDC-79E6-41FF-B0D7-34826138C264'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''3C93F78F-813F-45E5-8A92-C194208207EF'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''42239B9C-783B-4447-BAD5-3A3A1F17E199'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''45657978-69E6-4A07-AD72-5FD48B616279'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''4577D411-0EC4-47C7-9DDF-8B4975E564B2'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''4755119E-BCF5-47D8-B20D-80DE63C97595'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''4781BD6F-3A14-4BE6-ADC4-83D58D949C0E'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''4A527B20-4DA2-4640-971B-2B16E07A94F2'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''4E0E2DD1-0892-40CA-BF05-67AA666A1A8A'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''57507F15-1C67-45A9-AA24-F759549DCDD0'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''5E6FAEDE-741C-41B0-B4DF-18C735B779F9'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''6A525555-B62A-404F-8D36-04B5152F279D'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''6B663BBD-AF82-4563-A29F-D5C9E9617766'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''6C1FAC80-B478-4B1A-A3A4-90026D87B3A7'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''6DE27F00-CF80-472B-A63B-4B0B076FFB3E'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''6F653ED0-2757-488E-B653-BBACCD6F5DEA'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''79902D97-C5B4-4AD6-BEE7-57480CFA274D'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''8DD1F9C5-CAF8-4B39-86CE-1B08E8E752B4'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''91FBF8FA-80C5-4C57-A667-7B11D7FE1D65'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''94B6F2C3-46A6-4ABA-8E4C-DEA99AEDF865'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''954CF155-F277-4ECC-96B8-580B9E40F53C'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''96CA3862-A11E-4C69-967F-11026B74A939'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''99224BB3-7EA1-4BC2-A0E7-41173D1D5F7C'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''9933B268-0477-417F-B008-33E1F246E393'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''9BEB94AD-08C1-428C-90B9-C998264E7B70'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''9D9635E2-FB07-4BB9-A97F-E41507EAEDB8'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''9FC7578E-E6E0-4B57-B653-1EC055988280'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''A611DA37-3A9D-4A62-8348-7DC1A3A9EE3A'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''ADB275E7-712B-4687-91F8-8D836A34A7D3'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''B35BFEE7-F6F0-45CE-97EC-5A3171CBC334'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''B9578C50-8A52-4894-8156-2D16D908320B'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''BFB6D8BD-4B7B-4F50-98ED-CFD0095E17FA'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''C2DE3C69-9E00-4E21-8EFD-EC7B98452255'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''C432368B-862C-427A-ACED-63A005280EA0'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''CB387615-1744-4288-B246-D55CC85D3E7E'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''CD6D8923-9471-4354-BAFD-67EACDBF2C59'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''D1A0E7E8-FD6F-4C3D-865E-AB7559A362AC'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''F0CB81C2-8AB1-45C8-BF06-E9F635CC489C'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''F2B4CA25-B7A3-4D73-9734-8748E8D73AC0'', @enabled = 0
		exec msdb..sp_update_job @job_name = ''FA77CFC8-5F45-4E1D-BF7E-3C1EB99DFBD8'', @enabled = 0


END
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


