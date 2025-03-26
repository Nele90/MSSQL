USE [DBA_DB]
GO

CREATE TABLE [dbo].[BackupTbl_Backup_History](
	[database_name] [nvarchar](128) NULL,
	[backup_start_date] [datetime] NULL,
	[backup_finish_date] [datetime] NULL,
	[backup_type] [varchar](25) NULL,
	[DurationTime HH:MM] [nvarchar](21) NULL,
	[server_name] [nvarchar](128) NULL,
	[software_name] [nvarchar](128) NULL,
	[Who Perform backup] [nvarchar](128) NULL,
	[expiration_date] [datetime] NULL,
	[BackupName] [nvarchar](128) NULL,
	[BackupDescription] [nvarchar](255) NULL,
	[BackupSize in MB] [numeric](10, 2) NULL,
	[physical_device_name] [nvarchar](260) NULL,
	[first_lsn] [numeric](25, 0) NULL,
	[last_lsn] [numeric](25, 0) NULL,
	[checkpoint_lsn] [numeric](25, 0) NULL,
	[recovery_model] [nvarchar](60) NULL,
	[database_backup_lsn] [numeric](25, 0) NULL,
	[is_damaged] [bit] NULL,
	[has_incomplete_metadata] [bit] NULL,
	[Number of Backed Up Files] [int] NULL,
	[Number of Backed Up Filegroups] [int] NULL
) ON [PRIMARY]
GO


