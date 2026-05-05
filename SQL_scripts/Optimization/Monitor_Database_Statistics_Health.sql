SELECT s.name AS statistic_name, s.auto_created, s.user_created,
s.no_recompute, s.is_incremental, s.is_temporary, s.has_filter,
p.last_updated, DATEDIFF(day,p.last_updated, SYSDATETIME()) AS days_past,
h.name AS schema_name, o.name AS table_name, c.name AS column_name,
p.rows, p.rows_sampled, p.steps, p.modification_counter
FROM sys.stats AS s
JOIN sys.stats_columns i
ON s.stats_id = i.stats_id AND s.object_id = i.object_id
JOIN sys.columns c
ON c.object_id = i.object_id AND c.column_id = i.column_id
JOIN sys.objects o
ON s.object_id = o.object_id
JOIN sys.schemas h
ON o.schema_id = h.schema_id
OUTER APPLY sys.dm_db_stats_properties (s.object_id,s.stats_id) AS p
WHERE OBJECTPROPERTY(o.object_id, N’IsMSShipped’) = 0
ORDER BY days_past DESC;
