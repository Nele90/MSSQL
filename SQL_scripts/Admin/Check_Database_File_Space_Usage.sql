SELECT  
  ds.name as filegroupname
  , df.name AS 'FileName'  
  , physical_name AS 'PhysicalName'
  , size/128 AS 'TotalSizeinMB'
  , size/128.0 - CAST(FILEPROPERTY(df.name, 'SpaceUsed') AS int)/128.0 AS 'AvailableSpaceInMB'  
  , CAST(FILEPROPERTY(df.name, 'SpaceUsed') AS int)/128.0 AS 'ActualSpaceUsedInMB'
  , (CAST(FILEPROPERTY(df.name, 'SpaceUsed') AS int)/128.0)/(size/128)*100. as '%SpaceUsed'
FROM sys.database_files df LEFT OUTER JOIN sys.data_spaces ds
ON df.data_space_id = ds.data_space_id;
GO   
