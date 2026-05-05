SELECT
	OBJECT_SCHEMA_NAME(i.object_id),
	OBJECT_NAME(i.object_id),
	*
FROM 
	sys.dm_db_index_usage_stats ius 
		JOIN 
sys.indexes i ON ius.OBJECT_ID = i.OBJECT_ID AND ius.index_id = i.index_id
