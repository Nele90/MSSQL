Create PROCEDURE DatabaseFileFreeSpace 
(@Database_Name sysname = NULL, @TotalSizeMB int, @FreeFileSpace int)
AS   
CREATE TABLE #Results ([Database Name] sysname, 
[File Name] sysname, 
[Physical Name] NVARCHAR(260),
[File Type] VARCHAR(4), 
[Total Size in Mb] INT, 
[Available Space in Mb] INT) 

 DECLARE @SQL VARCHAR(5000) 
SELECT @SQL =    
'USE [?] INSERT INTO #Results([Database Name], [File Name], [Physical Name],    
[File Type], [Total Size in Mb], [Available Space in Mb])    
SELECT DB_NAME() AS DatabaseName,   
[name] AS [File Name],    
physical_name AS [Physical Name],    
[File Type] =    
	CASE type   
	WHEN 0 THEN ''Data''
			   WHEN 1 THEN ''Log''
		   END,   
	[Total Size in Mb] =   
	CASE ceiling([size]/128)    
	WHEN 0 THEN 1   
	ELSE ceiling([size]/128)   
	END,   
	[Available Space in Mb] =    
	CASE ceiling([size]/128)   
	WHEN 0 THEN (1 - CAST(FILEPROPERTY([name], ''SpaceUsed'') as int) /128)   
	ELSE (([size]/128) - CAST(FILEPROPERTY([name], ''SpaceUsed'') as int) /128)   
	END
FROM sys.database_files    
ORDER BY [File Type], [file_id]'   
--Run the command against each database   
EXEC sp_MSforeachdb @SQL   

--calculate free space % and insert into final table to sent email
 select *, CEILING(CAST([Available Space in Mb] AS decimal(10,1))/[Total Size in Mb]*100) AS [FreeSpace %], CAST([Total Size in Mb]*0.05 + [Total Size in Mb] as int) as [Extend5%]
 INTO #FinalDataSize
 from #Results
 ORDER BY [Total Size in Mb] DESC

--Send email fi Freespace is less than 5% and file size grather than 2gb
IF EXISTS (SELECT 1 FROM #FinalDataSize WHERE  [FreeSpace %] <@FreeFileSpace and [Total Size in Mb] > @TotalSizeMB)
DECLARE @xml NVARCHAR(MAX)
declare @body varchar(max)


SET @xml = CAST (( SELECT @@SERVERNAME AS 'td','', [Database Name] AS 'td','', [File Name] AS 'td','', [Physical Name] AS 'td','', [File Type] AS 'td','', [Total Size in Mb] AS 'td','', 
	CASE WHEN [Available Space in Mb] < 2000 THEN convert(XML,concat('<font color="red">',[Available Space in Mb],'</font>')) 
	ELSE CONVERT(varchar,[Available Space in Mb]) 
	END AS 'td','',
	CASE WHEN [FreeSpace %] < 5 THEN convert(XML,concat('<font color="red">',[FreeSpace %],'</font>')) 
	ELSE CONVERT(varchar,[FreeSpace %]) 
	END AS 'td','', 'ALTER DATABASE ' + '[' +[Database Name] + ']' + ' MODIFY FILE ( NAME = N' +'''' + [File Name]+ '''' +', SIZE =' + CONVERT(varchar,[Extend5%]) +'MB' + ')' AS 'td',''
FROM #FinalDataSize
WHERE [FreeSpace %] < @FreeFileSpace and [Total Size in Mb] > @TotalSizeMB
ORDER BY [Total Size in Mb] DESC
FOR XML PATH('tr'), Elements ) AS NVARCHAR(MAX))

SET @body ='<html><body><H3>SQL Data&Log file space</H3>
<table border = 1> 
<tr>
<th> SqlInstance </th> <th> DatabaseName </th> <th>  File Name </th> <th>  Physical Name </th> <th>  File Type </th> <th>  Total Size in Mb </th> <th>  Available Space in Mb </th> <th>  FreeSpace % </th> <th> Command </th>'    


SET @body = @body + @xml +'</table></body></html>'
EXEC msdb.dbo.sp_send_dbmail
@profile_name = 'SQL_DBA_mail',
@body = @body,
@body_format ='HTML',
@recipients = 'Nenad.Radevic@sma-magnetics.com',
@subject = 'SQL Data&Log file space';

DROP TABLE #FinalDataSize
DROP TABLE #Results
