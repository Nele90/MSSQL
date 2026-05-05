SELECT session_id, start_time, status,
total_elapsed_time,
CASE transaction_isolation_level
WHEN 1 THEN 'ReadUncomitted'
WHEN 2 THEN 'ReadCommitted'
WHEN 3 THEN 'Repeatable'
WHEN 4 THEN 'Serializable'
WHEN 5 THEN 'Snapshot'
ELSE 'Unspecified' END AS transaction_isolation_level,
sh.text, ph.query_plan
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_sql_text(sql_handle) sh
CROSS APPLY sys.dm_exec_query_plan(plan_handle) ph
