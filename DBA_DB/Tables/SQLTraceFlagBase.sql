USE [DBA_DB]
GO

CREATE TABLE [dbo].[SQLTraceFlagBase](
	[TraceFlag] [nvarchar](40) NULL,
	[Status] [tinyint] NULL,
	[GLOBAL] [tinyint] NULL,
	[SESSION] [tinyint] NULL
) ON [PRIMARY]
GO
