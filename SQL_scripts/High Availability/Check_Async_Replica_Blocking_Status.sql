SELECT CASE  WHEN availability_mode = 0	--check if replica is asynchronous
		AND EXISTS (SELECT *
					FROM sys.dm_exec_requests AS r		
					WHERE user_id = 1		--sa
						AND ISNULL(r.blocking_session_id, 0) <> 0)	-- check if there is a blocking session
		THEN 1
		ELSE 0 END
FROM sys.availability_replicas AS repl
WHERE repl.replica_server_name = @@SERVERNAME 
