SELECT 
	OBJECT_SCHEMA_NAME(i.object_id),
	OBJECT_NAME(i.object_id),
	* 
FROM 
	sys.dm_db_index_physical_stats(NULL,NULL,NULL,NULL,NULL) ips
		JOIN
	sys.indexes i ON ips.OBJECT_ID = i.OBJECT_ID AND ips.index_id = i.index_id

IndexOptimize checks avg_fragmentation_in_percent in sys.dm_db_index_physical_stats to determine the fragmentation.
