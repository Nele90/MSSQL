USE [DBA_DB]
GO

CREATE TABLE [dbo].[SQLReportBase](
	[Name] [nvarchar](425) NOT NULL,
	[Path] [nvarchar](425) NOT NULL,
	[UserName] [nvarchar](260) NULL,
	[CreationDate] [datetime] NOT NULL
) ON [PRIMARY]
GO


