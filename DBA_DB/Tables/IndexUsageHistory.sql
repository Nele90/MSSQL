USE DBA_DB
GO

CREATE TABLE IndexUsageHistory(
  [database_id] [smallint] NOT NULL,
  [object_id] [int] NOT NULL,
  [index_id] [int] NOT NULL,
  [user_seeks] [bigint] NOT NULL,
  [user_scans] [bigint] NOT NULL,
  [user_lookups] [bigint] NOT NULL,
  [user_updates] [bigint] NOT NULL,
  [last_user_seek] [datetime] NULL,
  [last_user_scan] [datetime] NULL,
  [last_user_lookup] [datetime] NULL,
  [last_user_update] [datetime] NULL,
  [system_seeks] [bigint] NOT NULL,
  [system_scans] [bigint] NOT NULL,
  [system_lookups] [bigint] NOT NULL,
  [system_updates] [bigint] NOT NULL,
  [last_system_seek] [datetime] NULL,
  [last_system_scan] [datetime] NULL,
  [last_system_lookup] [datetime] NULL,
  [last_system_update] [datetime] NULL,
  [last_poll_user_seeks] [bigint] NOT NULL,
  [last_poll_user_scans] [bigint] NOT NULL,
  [last_poll_user_lookups] [bigint] NOT NULL,
  [last_poll_user_updates] [bigint] NOT NULL,
  [last_poll_system_seeks] [bigint] NOT NULL,
  [last_poll_system_scans] [bigint] NOT NULL,
  [last_poll_system_lookups] [bigint] NOT NULL,
  [last_poll_system_updates] [bigint] NOT NULL,
  [date_stamp] [datetime] NOT NULL
) ON [PRIMARY]
