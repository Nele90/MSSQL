USE [DBA_DB]
GO

CREATE   PROC [dbo].[DiskSpaceAvalable]

(
	@Percentage int, 
	@AvalableSizeMB INT
)
AS
BEGIN
;WITH 
Disks
AS
(
SELECT DISTINCT @@SERVERNAME as servername, volume_mount_point,logical_volume_name, 
				CAST(TOTAL_BYTES / 1048576 as decimal(12,2)) [Total Space MBs],
			CAST(available_bytes / 1048576 as decimal(12,2)) [AvailableMBs],
			(CAST(available_bytes / 1048576 as decimal(12,2)) / 
			CAST(TOTAL_BYTES / 1048576 as decimal(10,2)) * 100) [Percentage]
FROM sys.master_files AS f  
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
)
SELECT servername, volume_mount_point + logical_volume_name as DiskName, [Total Space MBs], AvailableMBs, CAST([Percentage] as decimal(5,2)) as PercentageAvailable
INTO #FinalDiskTable
FROM Disks

IF EXISTS (SELECT 1 FROM #FinalDiskTable WHERE PercentageAvailable < @Percentage or AvailableMBs < @AvalableSizeMB)
 BEGIN 
--Send email 
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)

SET @xml = CAST (( SELECT servername AS 'td','', DiskName AS 'td','', [Total Space MBs] AS 'td','', 
		CASE 
		WHEN AvailableMBs < 10000 THEN convert(XML,concat('<font color="red">',AvailableMBs,'</font>')) 
		ELSE CONVERT(varchar,AvailableMBs)
		END AS 'td','',	
		CASE 
		WHEN PercentageAvailable < 10 THEN convert(XML,concat('<font color="red">',PercentageAvailable,'</font>')) 
		ELSE CONVERT(varchar,PercentageAvailable)
		END AS 'td',''
FROM #FinalDiskTable
WHERE PercentageAvailable < @Percentage or AvailableMBs < @AvalableSizeMB
FOR XML PATH('tr'), Elements ) AS NVARCHAR(MAX))

SET @body ='<html><body><H3>SQL Disk Space Check</H3>
<table border = 1> 
<tr>
<th> Servername </th> <th> DiskName </th> <th>  TotalSpaceMBs </th> <th>  AvailableMBs </th> <th>  PercentageAvailable </th>'    


SET @body = @body + @xml +'</table></body></html>'

EXEC msdb.dbo.sp_send_dbmail
@profile_name = 'SQL_DBA_mail',
@body = @body,
@body_format ='HTML',
--@recipients = 'Nenad.Radevic@sma-magnetics.com',
@recipients = 'Nenad.Radevic@sma-magnetics.com;lukasz.seremak@sma-magnetics.com;Taras.Vasyliuk@sma-magnetics.com',
@subject = 'SQL Disk Space Check';
END
DROP TABLE #FinalDiskTable
END
GO


