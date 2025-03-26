USE [DBA_DB]
GO
CREATE TABLE [dbo].[ObjectUsageByCPU](
	[InsertDate] [datetime] NOT NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[DatabaseID] [smallint] NULL,
	[ObjectID] [int] NULL,
	[SchemaName] [nvarchar](128) NULL,
	[ObjectType] [nvarchar](20) NOT NULL,
	[Objects] [nvarchar](128) NULL,
	[Total_Execution_count] [int] NULL,
	[Total_CPU_Time] [bigint] NULL,
	[Avg_CPU_Time] [numeric](34, 14) NULL
) ON [PRIMARY]
GO


