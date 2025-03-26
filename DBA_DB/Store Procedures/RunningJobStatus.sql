CREATE PROC RunningJobStatus
AS	
BEGIN

DROP TABLE IF EXISTS #TempResult
DROP TABLE IF EXISTS #Result
DROP TABLE IF EXISTS #JobInfo
DROP TABLE IF EXISTS #History

--Query all running jobs, using DateFormating function to convert run_requseted_date to be in "DD:HH:MM:SS" fashion, insert output into temp tbl "#JobInfo" 
SELECT j.name AS 'JobName', j.job_id AS 'JobID', ST.step_name, ST.step_id, a.run_requested_date AS 'ExecutionDate', [dbo].[DateFormating] (a.run_requested_date) AS 'ElapsedJobTime', last_executed_step_id + 1 AS CurrentStep,
stop_execution_date, last_executed_step_date, run_requested_date, j.name
INTO #JobInfo
FROM msdb.dbo.sysjobs_view j
INNER JOIN msdb.dbo.sysjobactivity a ON j.job_id = a.job_id
INNER JOIN msdb.dbo.syssessions s ON s.session_id = a.session_id
INNER JOIN msdb.dbo.sysjobsteps AS ST ON j.job_id = ST.job_id
INNER JOIN (
		SELECT MAX(agent_start_date) AS max_agent_start_date
		FROM msdb.dbo.syssessions
		) s2 ON s.agent_start_date = s2.max_agent_start_date
	WHERE stop_execution_date IS NULL
		AND run_requested_date IS NOT NULL

--Insert into temp tbl "history" which will return steps_id > 1 only for active jobs, it will convert time to be in  "DD:HH:MM:SS" fashion. Step_id = 0 is job outcome so that is filtered out.
SELECT msdb.dbo.agent_datetime(H.run_date, H.run_time) AS START_TIME,
STUFF(STUFF(RIGHT('000000' + CAST ( H.run_duration AS VARCHAR(6 ) ) ,6),5,0,':'),3,0,':') AS DURATION,
CONVERT(datetime, msdb.dbo.agent_datetime(H.run_date, H.run_time)) +
CONVERT(datetime, STUFF(STUFF(RIGHT('000000' + CAST ( H.run_duration AS VARCHAR(6 ) ) ,6),5,0,':'),3,0,':') ) AS END_TIME, H.job_id, H.step_name, H.step_id, H.instance_id, H.run_duration, H.run_time, H.run_status,H.run_date
INTO #History
from msdb.dbo.sysjobhistory AS H
WHERE H.step_id >= 1 AND H.job_id IN (SELECT J.JobID FROM #JobInfo as j) and msdb.dbo.agent_datetime(H.run_date, H.run_time) >= DATEADD(Day, -14, GETDATE()) and run_status <> 3

--Insert into temp tbl "#TempResult" history which is older than one day.
SELECT DISTINCT 
JI.JobID, JI.step_id, JI.step_name, JI.run_requested_date, JI.stop_execution_date, JI.last_executed_step_date, JI.name, H.DURATION
INTO #TempResult
FROM #JobInfo AS JI
LEFT JOIN #History AS H
ON JI.JobID = H.job_id AND JI.step_id = H.step_id AND JI.run_requested_date <= H.START_TIME

/*The follwoing 4 CTEs will do next things:
It will partition by jobs steps and it will add for the first step of the job it will pass start time of job, and for every other step i will take the previous end step time
*/
;WITH CTE AS
(
	SELECT msdb.dbo.agent_datetime(run_date, run_time) AS START_TIME, instance_id, job_id, step_id, step_name, ROW_Number() OVER(ORDER BY instance_id) AS A
	FROM msdb.dbo.sysjobhistory AS H
	WHERE H.job_id IN (SELECT J.JobID FROM #JobInfo as j)
	), CTE1 
AS
(	SELECT *, A-step_id AS B
	FROM CTE
), CTE2 
AS 
(
	SELECT *, LAG(START_TIME, 1,0) OVER(PARTITION BY B ORDER BY instance_id) AS StartDate
	FROM CTE1 
), CTE3
AS 
(
	SELECT DISTINCT C.*, T.Duration, START_TIME AS PreviousTime, LAG(T.Duration, 1,'00:00:00') OVER(PARTITION BY B ORDER BY instance_id) AS PreviousDuration
	FROM CTE2 AS C
	INNER JOIN #TempResult AS T
	ON C.job_id = T.JobID AND C.step_id = T.step_id
), CTE4 
AS
(
	SELECT *, Cast(PreviousTime AS datetime) + CAST(DURATION as datetime) AS PreviousStepDuration,  ROW_NUMBER() OVER(PARTITION BY job_id, step_id ORDER BY Instance_id DESC) AS Partitons
	FROM CTE3
), CTE5 AS
(
	SELECT job_id ,step_id, Duration,[dbo].[DateFormating] (PreviousStepDuration) AS 'StepDurationWrongRow', PreviousDuration = IIF(step_id >=1, START_TIME, PreviousDuration)
	FROM CTE4
	WHERE Partitons = 1
), CTe6
AS 
(
	SELECT *, LAG(StepDurationWrongRow, 1) OVER(PARTITION BY job_id ORDER BY step_id) AS ElapsedStepTime
	FROM CTE5
)
SELECT *
INTO #Result
FROM CTe6

--This two ctes will do AVG step duration and AVG job duration
;WITH JobStep
AS (
SELECT 
H.job_id, H.step_id, H.step_name, AVG(H.run_duration) AS AVGStepDuration
FROM #History H
GROUP BY H.job_id, H.step_id, H.step_name
), JobAVG
	AS
	(
	SELECT H.job_id, AVG(H.run_duration) AS AVGjobRunTime 
	FROM msdb..sysjobhistory AS H
	where step_id = 0
GROUP BY H.job_id
), CurrentStepRun 
AS
(
/*As there was an issue with "last_executed_step_id" when the job is run from any step expect step1 this columns is null. 
And the workaround for this issue is to query "dm_exec_sessions" and find what step job is running at.
*/
	SELECT REPLACE(SUBSTRING(program_name, (PATINDEX('%: Step%',program_name)+7),LEN(program_name)-1),')', '') AS CurrentStep, CAST(B.job_id as uniqueidentifier) AS job_id
	from sys.dm_exec_sessions as a
	inner join msdb.dbo.sysjobs b on b.job_id = cast(convert( binary(16), substring(a.program_name , 30, 34), 1) as uniqueidentifier)
	WHERE  program_name like 'SQLAgent - TSQL JobStep (Job % : Step %)'
)
--Last query is to join all temp tbls on job and step ids, formating columns and  whichever step is executed it will have duration. 
SELECT DISTINCT JI.JobID, JI.JobName, JI.step_id as StepId, JI.step_name AS StepName, JI.ExecutionDate,  JI.ElapsedJobTime,
(STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(JA.AVGjobRunTime as varchar(8)), 8), 3, 0, ':'), 6, 0, ':'),9, 0, ':')) 'AvgJobDuration',
(STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(JS.AVGStepDuration as varchar(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':')) 'AvgStepDuration ',
CASE 
	WHEN CS.CurrentStep > JI.step_id THEN R.DURATION
	WHEN CS.CurrentStep = JI.step_id THEN R.ElapsedStepTime
	ELSE NULL
END AS [ElapsedSetpTime], CS.CurrentStep 
FROM #JobInfo AS JI
LEFT JOIN JobStep as JS
ON JI.JobID = JS.job_id AND JI.step_id = JS.step_id
LEFT JOIN JobAVG as JA
ON JI.JobID = JA.job_id 
LEFT JOIN #Result AS R
ON JI.JobID = R.job_id AND JI.step_id = R.step_id
LEFT JOIN CurrentStepRun AS CS
ON JI.JobID = CS.job_id	
END