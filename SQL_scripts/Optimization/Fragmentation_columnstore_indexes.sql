SELECT i.object_id,
OBJECT_NAME(i.object_id) AS table_name,
i.name AS index_name,
i.index_id,
i.type_desc,
100*(ISNULL(deleted_rows,0))/total_rows AS ‘Fragmentation’,
s.*
FROM sys.indexes AS i
JOIN sys.dm_db_column_store_row_group_physical_stats AS s
ON i.object_id = s.object_id AND i.index_id = s.index_id
ORDER BY fragmentation DESC;
