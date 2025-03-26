USE [DBA_DB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[RestoreHistory](
	[restore_history_id] [int] IDENTITY(1,1) NOT NULL,
	[restore_date] [datetime] NULL,
	[destination_database_name] [nvarchar](128) NULL,
	[user_name] [nvarchar](128) NULL,
	[backup_set_id] [int] NOT NULL,
	[restore_type] [char](1) NULL,
	[replace] [bit] NULL,
	[recovery] [bit] NULL,
	[restart] [bit] NULL,
	[stop_at] [datetime] NULL,
	[device_count] [tinyint] NULL,
	[stop_at_mark_name] [nvarchar](128) NULL,
	[stop_before] [bit] NULL
) ON [PRIMARY]
GO


