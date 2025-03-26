CREATE TABLE [dbo].[SysadminBase]
(
		[login] [sysname] NOT NULL,
		[status] [varchar](8) NOT NULL,
		[type] [nvarchar](60) NULL,
		[create_date] [datetime] NOT NULL,
		[modify_date] [datetime] NOT NULL
)
GO