SELECT DISTINCT DB_NAME(s.database_id) AS database_name,
s.database_id, s.volume_mount_point, s.volume_id,
s.logical_volume_name, s.file_system_type, s.total_bytes, s.available_bytes,
((s.available_bytes*1.0)/s.total_bytes) as percent_free
FROM sys.master_files AS f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) AS s;
