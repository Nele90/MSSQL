USE [DBA_DB]
GO

CREATE TABLE [dbo].[UnusedIndexes](
	[InsertDate] [datetime] NOT NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [sysname] NOT NULL,
	[TableName] [sysname] NOT NULL,
	[IndexName] [sysname] NULL,
	[IndexUpdates] [bigint] NOT NULL,
	[UserLookups] [bigint] NOT NULL,
	[UserSeeks] [bigint] NOT NULL,
	[UserScans] [bigint] NOT NULL
) ON [PRIMARY]
GO
