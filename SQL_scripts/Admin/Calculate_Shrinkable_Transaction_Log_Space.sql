-- change to database scope
IF OBJECT_ID ('tempdb..#TempForLogInfo') IS NOT NULL  
DROP TABLE #TempForLogInfo 
GO  
CREATE TABLE #TempForLogInfo
(
FileID numeric,
FileSize numeric,
StartOffset numeric,
FseqNo numeric,
Status numeric,
Parity numeric,
CreateLSN numeric (25,0)
)
declare @sql_command varchar(50)
SELECT @sql_command = 'dbcc loginfo' 
INSERT INTO #TempForLogInfo EXEC (@sql_command)
select * from #TempForLogInfo
declare @FseqNoMax numeric
set @FseqNoMax = (select MAX(FseqNo) from #TempForLogInfo)
--determine the head of log
--select @FseqNoMax
declare @StartOffset numeric
set @StartOffset = (select StartOffset from #TempForLogInfo where FseqNo = @FseqNoMax ) 
--determine the startoffset for log head
--select @StartOffset
declare @FS numeric
declare @SOFF numeric
declare @S numeric
declare @SumFSSOFF numeric (25,2) = 0
declare db_cursor cursor for 
select t.FileSize , t.StartOffset, t.Status
from #TempForLogInfo t where StartOffset > @StartOffset
declare @counter int = 0
open db_cursor
fetch next from db_cursor into @FS, @SOFF, @S
While @@FETCH_STATUS = 0
Begin
if @S = 0 
begin
if @counter = 0
begin
set @SumFSSOFF =  @SOFF + @FS
set @counter = 1
end
end
else
begin
set @SumFSSOFF = 0
set @counter = 0
end
fetch next from db_cursor into @FS, @SOFF, @S
End
close db_cursor
deallocate db_cursor
-- determine the bytes that can be shrink
--select @SumFSSOFF
set @SumFSSOFF = @SumFSSOFF/(1024 * 1024)
select @SumFSSOFF as ShrinkSize_MB
DROP TABLE #TempForLogInfo
