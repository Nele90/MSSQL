USE [DBA_DB]
GO

CREATE TABLE [dbo].[MissingIndexes](
	[InsertDate] [datetime] NOT NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[SchemaName] [nvarchar](128) NULL,
	[TableName] [nvarchar](128) NULL,
	[Estimated Index Uses] [bigint] NOT NULL,
	[Estimated Index Impact %] [float] NULL,
	[Estimated Avg Query Cost] [float] NULL,
	[Create TSQL] [nvarchar](4000) NULL,
	[equality_columns] [nvarchar](4000) NULL,
	[inequality_columns] [nvarchar](4000) NULL,
	[included_columns] [nvarchar](4000) NULL,
	[unique_compiles] [bigint] NOT NULL,
	[last_user_seek] [datetime] NULL
) ON [PRIMARY]
GO

