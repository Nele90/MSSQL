USE [msdb]
GO

/****** Object:  Job [DBA: Backup_Cleanup_Files]    Script Date: 2/2/2024 11:33:58 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Database Maintenance]]    Script Date: 2/2/2024 11:33:58 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Database Maintenance]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Database Maintenance]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Backup_Cleanup_Files', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Database Maintenance]', 
		@owner_login_name=N'sma\radevic_admin', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check_node]    Script Date: 2/2/2024 11:33:58 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_node', 
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
	PRINT ''Go to the next step''
END
ELSE
BEGIN
	RAISERROR(''This is not an important message.'', 11, 1);
END
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete_backup_files_older_30_days]    Script Date: 2/2/2024 11:33:58 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete_backup_files_older_30_days', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'import-module az.storage
import-module Az.Accounts

$Retention = (Get-date).AddDays(-30)
$StorageAccountName = "StorageAccountName"
$Containername = "ContainerName"
$ExtensionBak = "*.bak"
$ExtensionTrn = "*.trn"
$logFilePath = "C:\Cleanup_Backup_files\cleanup_backup_files"+(Get-Date -f yyyyMMddHHmm)+".txt"
$logFilePath1 = "C:\Cleanup_Backup_files\cleanup_backup_log_files"+(Get-Date -f yyyyMMddHHmm)+".txt"
$StorageAccountKey = "accountkey"
$StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
$Blob = Get-AzStorageBlob -Container $Containername -Context $StorageContext
$Blob | Where-Object { $_.LastModified.UtcDateTime -lt $Retention -and $_.Name -like $ExtensionBak} | Remove-AzStorageBlob -Verbose *> $logFilePath #| FL
$Blob | Where-Object { $_.LastModified.UtcDateTime -lt $Retention -and $_.Name -like $ExtensionTrn} | Remove-AzStorageBlob -Verbose *> $logFilePath1 #| FL
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [delete_backup_output_files]    Script Date: 2/2/2024 11:33:58 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'delete_backup_output_files', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Get-ChildItem –Path "C:\Cleanup_Backup_files\*.txt" | Where-Object{$_.CreationTime –lt (Get-Date).AddDays(-30)} | Remove-Item', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dailiy at 11pm', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230220, 
		@active_end_date=99991231, 
		@active_start_time=230000, 
		@active_end_time=235959, 
		@schedule_uid=N'ae384809-0d9e-4de0-bfcb-6ab63664c058'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


