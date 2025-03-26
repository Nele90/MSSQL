USE [DBA_DB]
GO

CREATE TABLE [dbo].[SQLConfigurationBase](
	[configuration_id] [int] NOT NULL,
	[name] [nvarchar](35) NOT NULL,
	[value] [sql_variant] NULL,
	[minimum] [sql_variant] NULL,
	[maximum] [sql_variant] NULL,
	[value_in_use] [sql_variant] NULL,
	[description] [nvarchar](255) NOT NULL,
	[is_dynamic] [bit] NOT NULL,
	[is_advanced] [bit] NOT NULL
) ON [PRIMARY]
GO


