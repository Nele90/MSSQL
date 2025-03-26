USE [DBA_DB]
GO

CREATE TABLE [dbo].[SQLLoginStatusBase](
	[name] [sysname] NOT NULL,
	[is_disabled] [bit] NULL
) ON [PRIMARY]
GO
