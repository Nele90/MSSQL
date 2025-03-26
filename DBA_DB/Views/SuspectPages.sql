CREATE VIEW [dbo].[SuspectPages]
AS
	SELECT d.name AS databaseName
		,mf.name AS logicalFileName
		,mf.physical_name AS physicalFileName
		,sp.page_id
		,CASE sp.event_type
			WHEN 1
				THEN N'823 or 824 error'
			WHEN 2
				THEN N'Bad Checksum'
			WHEN 3
				THEN N'Torn Page'
			WHEN 4
				THEN N'Restored'
			WHEN 5
				THEN N'Repaired'
			WHEN 7
				THEN N'Deallocated'
			END AS eventType
		,sp.error_count
		,sp.last_update_date
	FROM msdb.dbo.suspect_pages AS sp
		INNER JOIN sys.databases AS d 
			ON sp.database_id = d.database_id
		INNER JOIN sys.master_files AS mf 
			ON sp.[file_id] = mf.[file_id] AND d.database_id = mf.database_id;
