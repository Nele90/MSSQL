USE [DBA_DB]
GO

/****** Object:  Table [dbo].[SQL_Updates]    Script Date: 27.02.2024 15:33:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQL_Updates](
	[InsertDate] [datetime] NULL,
	[Build] [nvarchar](50) NULL,
	[BuildLevel] [nvarchar](50) NULL,
	[BuildTarget] [nvarchar](50) NULL,
	[Compliant] [nvarchar](50) NULL,
	[CULevel] [nvarchar](10) NULL,
	[CUTarget] [nvarchar](10) NULL,
	[KBLevel] [int] NULL,
	[MatchType] [nvarchar](50) NULL,
	[MaxBehind] [nvarchar](10) NULL,
	[NameLevel] [int] NULL,
	[SPLevel] [nvarchar](10) NULL,
	[SPTarget] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[SupportedUntil] [datetime] NULL,
	[Warning] [nvarchar](100) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQL_Updates] ADD  DEFAULT (getdate()) FOR [InsertDate]
GO
