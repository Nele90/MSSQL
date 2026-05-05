SELECT CASE WHEN repl.availability_mode = 1 THEN (SUM(st.log_send_queue_size) + SUM(st.redo_queue_size)) / 1024
		ELSE 0 END AS [replication falling behind]
FROM sys.dm_hadr_database_replica_states AS st
	INNER JOIN sys.availability_replicas AS repl
		ON st.group_id = repl.group_id AND st.replica_id = repl.replica_id
WHERE repl.replica_server_name = @@SERVERNAME 
	-- Reindex job running fom 20:00 and running up to 2 hours
	AND CONVERT(time, GETDATE()) NOT BETWEEN CONVERT(time, '20:00') AND CONVERT(time, '22:00')
GROUP BY repl.availability_mode
