SELECT 
		T1.step_id AS [Step_id],
T1.step_name AS [Step Name],
SUBSTRING(T2.name,1,140) AS [SQL Job Name],
msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
CAST(CONVERT(DATETIME,CAST(run_date AS CHAR(8)),101) AS CHAR(11)) AS [Failure Date],
msdb.dbo.agent_datetime(T1.run_date, T1.run_time) AS 'RunDateTime',
T1.run_duration StepDuration,
CASE T1.run_status
WHEN 0 THEN 'Failed'
WHEN 1 THEN 'Succeeded'
WHEN 2 THEN 'Retry'
WHEN 3 THEN 'Cancelled'
WHEN 4 THEN 'In Progress'
END AS ExecutionStatus,
T1.message AS [Error Message]
FROM
msdb..sysjobhistory T1 INNER JOIN msdb..sysjobs T2 ON T1.job_id = T2.job_id
where t1.run_status NOT IN (1, 4)
		AND T1.step_id != 0
AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (DAY,(-1), GETDATE())), 112)
