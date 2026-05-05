CREATE TABLE #databases
(
 DATABASE_NAME VARCHAR(50),
 DATABASE_SIZE FLOAT,
 REMARKS VARCHAR(100)
)
 
INSERT #Databases EXEC ('EXEC sp_databases');
 
SELECT @@SERVERNAME AS SERVER_NAME,
       DATABASE_NAME,
       SYSMFM.source_file_name_main,
       SYSMFM.physical_name_main,
       SYSMFL.source_file_name_log,
       SYSMFL.physical_name_log,
       DATABASE_SIZE AS '(KB)',
       ROUND(DATABASE_SIZE / 1024, 2) AS '(MB)',
       ROUND((DATABASE_SIZE / 1024) / 1024, 2) AS '(GB)',
       SYSDB.compatibility_level,
       SYSDB.create_date,
       SYSDB.database_id,
       SYSDB.collation_name,
       SYSDB.recovery_model,
       SYSDB.recovery_model_desc,
       SYSDB.user_access,
       SYSDB.user_access_desc,
       SYSDB.state,
       SYSDB.state_desc
  FROM #databases AS DB
       INNER JOIN sys.databases AS SYSDB ON DB.DATABASE_NAME = SYSDB.name
       INNER JOIN (SELECT database_id,
                          name AS source_file_name_main,
                          physical_name AS physical_name_main 
                     FROM sys.master_files AS SYSMF
                    WHERE SYSMF.file_id = 1) AS SYSMFM ON SYSMFM.database_id = SYSDB.database_id
       INNER JOIN (SELECT database_id,
                          name AS source_file_name_log,
                          physical_name AS physical_name_log 
                     FROM sys.master_files AS SYSMF
                    WHERE SYSMF.file_id = 2) AS SYSMFL ON SYSMFL.database_id = SYSDB.database_id
 WHERE SYSDB.database_id > 4
 ORDER BY DATABASE_SIZE desc;
 
DROP TABLE #databases;
