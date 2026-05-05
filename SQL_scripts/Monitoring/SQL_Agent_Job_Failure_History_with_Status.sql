USE msdb
SELECT DISTINCT-- h.server AS [Server],
       j.name AS JobName,
	   --h.step_name AS StepName, 
       h.run_date AS LastRunDate,
    --  h.run_time AS LastRunTime,
	    CASE h.run_status	   
		WHEN 0 THEN 'Failed'
		WHEN 1 THEN 'Succeeded'
		WHEN 2 THEN 'Retry'
		WHEN 3 THEN 'Cancelled'
		WHEN 4 THEN 'In Progress'
		END AS ExecutionStatus,
--j.message AS [Error Message],
h.message AS jobMessage
FROM msdb..sysjobhistory h
     JOIN msdb..sysjobs j ON h.job_id = j.job_id
WHERE h.run_status = 0
	--and j.step_id != 0
	AND h.run_date >= CONVERT(VARCHAR(10), GETDATE() -1, 112) 
 and h.step_id = 0
ORDER BY h.run_date DESC;
