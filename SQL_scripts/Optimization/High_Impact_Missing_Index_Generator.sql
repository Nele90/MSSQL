SELECT
mid.statement AS [Query Text]
  ,migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS [Impact],
  'CREATE INDEX [IX_'+LEFT (PARSENAME(mid.statement, 1), 32)+'_'
  +ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(mid.equality_columns, '[',''),',','_'),']',''),' ',''),'')+
  +ISNULL('_'+REPLACE(REPLACE(REPLACE(REPLACE(mid.inequality_columns, '[',''),',','_'),']',''),' ',''),'')+']'
  + ' ON ' + mid.statement
 + ' (' + ISNULL (mid.equality_columns,'')
    + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END
    + ISNULL (mid.inequality_columns, '')
  + ')'
  + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS [Index Create Script]
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10 and mid.database_id=DB_ID()
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC
