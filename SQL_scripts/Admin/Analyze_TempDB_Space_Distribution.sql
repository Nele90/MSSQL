SELECT 
(SUM(unallocated_extent_page_count)/128) AS [Free space (MB)],
SUM(internal_object_reserved_page_count)*8 AS [Internal objects (KB)],
SUM(user_object_reserved_page_count)*8 AS [User objects (KB)],
SUM(version_store_reserved_page_count)*8 AS [Version store (KB)]
FROM sys.dm_db_file_space_usage
--database_id '2' represents tempdb
WHERE database_id = 2
