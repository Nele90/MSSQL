USE msdb;
GO
SELECT h.server AS [Server],
       h.job_id,
       j.step_name AS [Name],
       h.message AS [Message],
       h.run_date AS LastRunDate,
       h.run_time AS LastRunTime
FROM dbo.sysjobhistory h
    INNER JOIN sysjobhistory j  ON h.job_id = j.job_id
WHERE h.run_status = 1
      AND h.instance_id IN
          (
              SELECT MAX(h.instance_id) FROM dbo.sysjobhistory h GROUP BY (h.job_id)
          )
      AND h.run_status = 0
      AND h.run_date >= CONVERT(VARCHAR(10), GETDATE(), 112)
ORDER BY h.run_date DESC;
