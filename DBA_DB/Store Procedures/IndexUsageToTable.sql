USE DBA_DB
GO

CREATE OR ALTER PROCEDURE IndexUsageToTable AS 
DECLARE @last_service_start_date datetime
DECLARE @last_data_persist_date datetime

--Determine last service restart date based upon tempdb creation date
SELECT @last_service_start_date =  SD.[create_date] FROM sys.databases SD WHERE SD.[name] = 'tempdb'

--Return the value for the last refresh date of the persisting table
SELECT @last_data_persist_date =  MAX(HIT.[date_stamp]) FROM [DBA_DB].[dbo].[IndexUsageHistory] HIT

--Take care of updated records first
IF @last_service_start_date < @last_data_persist_date
  BEGIN
     --Service restart date > last poll date
     PRINT 'The latest persist date was ' + 
        CAST(@last_data_persist_date AS VARCHAR(50)) + 
        '; no restarts occurred since ' + 
        CAST(@last_service_start_date AS VARCHAR(50)) +
        '  (' + CAST(DATEDIFF(d, @last_service_start_date, @last_data_persist_date) AS VARCHAR(10)) + 
        ' days ago.)'

     UPDATE HIT
     SET 
        HIT.[user_seeks] = HIT.[user_seeks]+(IXS.[user_seeks] - HIT.[last_poll_user_seeks]),
        HIT.[user_scans] = HIT.[user_scans]+(IXS.[user_scans] - HIT.[last_poll_user_scans]),
        HIT.[user_lookups] = HIT.[user_lookups]+(IXS.[user_lookups] - HIT.[last_poll_user_lookups]),
        HIT.[user_updates] = HIT.[user_updates]+(IXS.[user_updates] - HIT.[last_poll_user_updates]),
        HIT.[last_user_seek] = IXS.[last_user_seek],
        HIT.[last_user_scan] = IXS.[last_user_scan],
        HIT.[last_user_lookup] = IXS.[last_user_lookup],
        HIT.[last_user_update] = IXS.[last_user_update],
        HIT.[system_seeks] = HIT.[system_seeks]+(IXS.[system_seeks] - HIT.[last_poll_system_seeks]),
        HIT.[system_scans] = HIT.[system_scans]+(IXS.[system_scans] - HIT.[last_poll_system_scans]),
        HIT.[system_lookups] = HIT.[system_lookups]+(IXS.[system_lookups] - HIT.[last_poll_system_lookups]),
        HIT.[system_updates] = HIT.[system_updates]+(IXS.[system_updates] - HIT.[last_poll_system_updates]),
        HIT.[last_system_seek] = IXS.[last_system_seek],
        HIT.[last_system_scan] = IXS.[last_system_scan],
        HIT.[last_system_lookup] = IXS.[last_system_lookup],
        HIT.[last_system_update] = IXS.[last_system_update],
        HIT.[last_poll_user_seeks] = IXS.[user_seeks],
        HIT.[last_poll_user_scans] = IXS.[user_scans],
        HIT.[last_poll_user_lookups] = IXS.[user_lookups],
        HIT.[last_poll_user_updates] = IXS.[user_updates],
        HIT.[last_poll_system_seeks] = IXS.[system_seeks],
        HIT.[last_poll_system_scans] = IXS.[system_scans],
        HIT.[last_poll_system_lookups] = IXS.[system_lookups],
        HIT.[last_poll_system_updates] = IXS.[system_updates],
        HIT.date_stamp = GETDATE()
     FROM [sys].[dm_db_index_usage_stats] IXS INNER JOIN 
        [DBA_DB].[dbo].[IndexUsageHistory] HIT
           ON IXS.[database_id] = HIT.[database_id]
              AND IXS.[object_id] = HIT.[object_id]
              AND IXS.[index_id] = HIT.[index_id]
			  INNER JOIN sys.dm_db_partition_stats PS
			  ON IXS.object_id = PS.object_id
  END
ELSE
  BEGIN
     --Service restart date < last poll date
     PRINT 'Lastest service restart occurred on ' + 
        CAST(@last_service_start_date AS VARCHAR(50)) + 
        ' which is after the latest persist date of ' + 
        CAST(@last_data_persist_date AS VARCHAR(50))
     
     UPDATE HIT
     SET 
        HIT.[user_seeks] = HIT.[user_seeks]+ IXS.[user_seeks],
        HIT.[user_scans] = HIT.[user_scans]+ IXS.[user_scans],
        HIT.[user_lookups] = HIT.[user_lookups]+ IXS.[user_lookups],
        HIT.[user_updates] = HIT.[user_updates]+ IXS.[user_updates],
        HIT.[last_user_seek] = IXS.[last_user_seek],
        HIT.[last_user_scan] = IXS.[last_user_scan],
        HIT.[last_user_lookup] = IXS.[last_user_lookup],
        HIT.[last_user_update] = IXS.[last_user_update],
        HIT.[system_seeks] = HIT.[system_seeks]+ IXS.[system_seeks],
        HIT.[system_scans] = HIT.[system_scans]+ IXS.[system_scans],
        HIT.[system_lookups] = HIT.[system_lookups]+ IXS.[system_lookups],
        HIT.[system_updates] = HIT.[system_updates]+ IXS.[system_updates],
        HIT.[last_system_seek] = IXS.[last_system_seek],
        HIT.[last_system_scan] = IXS.[last_system_scan],
        HIT.[last_system_lookup] = IXS.[last_system_lookup],
        HIT.[last_system_update] = IXS.[last_system_update],
        HIT.[last_poll_user_seeks] = IXS.[user_seeks],
        HIT.[last_poll_user_scans] = IXS.[user_scans],
        HIT.[last_poll_user_lookups] = IXS.[user_lookups],
        HIT.[last_poll_user_updates] = IXS.[user_updates],
        HIT.[last_poll_system_seeks] = IXS.[system_seeks],
        HIT.[last_poll_system_scans] = IXS.[system_scans],
        HIT.[last_poll_system_lookups] = IXS.[system_lookups],
        HIT.[last_poll_system_updates] = IXS.[system_updates],
        HIT.date_stamp = GETDATE()
     FROM [sys].[dm_db_index_usage_stats] IXS INNER JOIN 
        [DBA_DB].[dbo].[IndexUsageHistory] HIT
           ON IXS.[database_id] = HIT.[database_id]
              AND IXS.[object_id] = HIT.[object_id]
              AND IXS.[index_id] = HIT.[index_id]
  END   

--Take care of new records next
     INSERT INTO [DBA_DB].[dbo].[IndexUsageHistory]
        (
        [database_id], [object_id], [index_id], 
        [user_seeks], [user_scans], [user_lookups],
        [user_updates], [last_user_seek], [last_user_scan],
        [last_user_lookup], [last_user_update], [system_seeks],
        [system_scans], [system_lookups], [system_updates],
        [last_system_seek], [last_system_scan], 
        [last_system_lookup], [last_system_update],
        [last_poll_user_seeks],    [last_poll_user_scans], 
        [last_poll_user_lookups], [last_poll_user_updates],
        [last_poll_system_seeks], [last_poll_system_scans], 
        [last_poll_system_lookups], [last_poll_system_updates],
        [date_stamp]
        )
     SELECT IXS.[database_id], IXS.[object_id], IXS.[index_id], 
        IXS.[user_seeks], IXS.[user_scans], IXS.[user_lookups],
        IXS.[user_updates], IXS.[last_user_seek], IXS.[last_user_scan],
        IXS.[last_user_lookup], IXS.[last_user_update], IXS.[system_seeks],
        IXS.[system_scans], IXS.[system_lookups], IXS.[system_updates],
        IXS.[last_system_seek], IXS.[last_system_scan], 
        IXS.[last_system_lookup], IXS.[last_system_update],
        IXS.[user_seeks], IXS.[user_scans], IXS.[user_lookups],
        IXS.[user_updates],IXS.[system_seeks],
        IXS.[system_scans], IXS.[system_lookups], 
        IXS.[system_updates], GETDATE()  
     FROM [sys].[dm_db_index_usage_stats] IXS LEFT JOIN 
        [DBA_DB].[dbo].[IndexUsageHistory] HIT
           ON IXS.[database_id] = HIT.[database_id]
           AND IXS.[object_id] = HIT.[object_id]
           AND IXS.[index_id] = HIT.[index_id]
     WHERE HIT.[database_id] IS NULL 
        AND HIT.[object_id] IS NULL
        AND HIT.[index_id] IS NULL