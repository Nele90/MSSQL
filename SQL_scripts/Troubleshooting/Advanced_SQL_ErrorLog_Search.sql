--EXEC #spReadAllErrorLogs 

--EXEC spReadAllErrorLogs
--Get all the available error log data from a certain date

--EXEC spReadAllErrorLogs
--   @FromDate = '20180320'
--Get all the available error log data between certain dates

--EXEC spReadAllErrorLogs
--   @FromDate = '20180320',
--   @ToDate = '2018-03-22 23:59'
--Get the content with messages containing the strings ‘Error’ and ‘Severity’

--EXEC spReadAllErrorLogs
--   @SearchString1 = 'ERROR',
--   @SearchString2 = 'Severity'
--Get the content since a certain date with messages containing the strings ‘Error’ and ‘Severity’

--EXEC spReadAllErrorLogs
--   @FromDate = '20180301',
--   @ToDate = NULL,
--   @SearchString1 = 'ERROR',
--   @SearchString2 = 'Severity'
--Get the content between two dates with messages containing the strings ‘Error’ and ‘Severity’

--EXEC spReadAllErrorLogs
--   @FromDate = '20180301',
--   @ToDate = '20180315',
--   @SearchString1 = 'ERROR',
--   @SearchString2 = 'Severity'
--Get the content between two dates with messages containing the strings ‘Error’ and ‘Severity’ + show the adjacent 1 row above and below the row with matching text

--EXEC spReadAllErrorLogs
--   @FromDate = '20180301',
--   @ToDate = '20180315',
--   @SearchString1 = 'Error',
--   @SearchString2 = 'Severity',
--   @SearchShowAdjacentLogsPlusMinus=1


CREATE PROCEDURE #spReadAllErrorLogs
   @FromDate DATETIME = NULL,
   @ToDate DATETIME = NULL,
   @SearchString1 NVARCHAR(255) = NULL,
   @SearchString2 NVARCHAR(255) = NULL,
   @SearchShowAdjacentLogsPlusMinus INT = 0  --Shows this many log records before and after the line matching "SearchString"
                                             --If there are multiple rows with the exact LogDate, "adjacent" becomes inaccurate ..still useful
AS
BEGIN
 
    /*
    v1.0  - Apr 19, 2018 - Jana Sattainathan [Twitter: @SQLJana] [Blog: sqljana.wordpress.com]
 
    ----------------------------
    Usage examples:
    ----------------------------
 
    --Get all the available error log data
    EXEC spReadAllErrorLogs 
 
    --Get all the available error log data from a certain date
    EXEC spReadAllErrorLogs @FromDate = '20180320'
 
    --Get all the available error log data between certain dates
    EXEC spReadAllErrorLogs @FromDate = '20180320', @ToDate = '2018-03-22 23:59' 
 
    --Get the content with messages containing the strings 'Error' and 'Severity'
    EXEC spReadAllErrorLogs @SearchString1 = 'ERROR', @SearchString2 = 'Severity'
 
    --Get the content since a certain date with messages containing the strings 'Error' and 'Severity'
    EXEC spReadAllErrorLogs @FromDate = '20180301', @ToDate = NULL, @SearchString1 = 'ERROR', @SearchString2 = 'Severity'
 
    --Get the content between two dates with messages containing the strings 'Error' and 'Severity'
    EXEC spReadAllErrorLogs @FromDate = '20180301', @ToDate = '20180315', @SearchString1 = 'ERROR', @SearchString2 = 'Severity'
 
    --Get the content between two dates with messages containing the strings 'Error' and 'Severity' +
    --  show the adjacent 1 row above and below the row with matching text
    EXEC spReadAllErrorLogs @FromDate = '20180301', @ToDate = '20180315', @SearchString1 = 'Error', @SearchString2 = 'Severity', @SearchShowAdjacentLogsPlusMinus=1
 
    */
 
    DECLARE @ArchiveNumber INT;
 
    IF object_id('TEMPDB.DBO.##TempLogList1') IS NOT NULL
        DROP TABLE ##TempLogList1;
    IF object_id('TEMPDB.DBO.#TempLogList2') IS NOT NULL
        DROP TABLE #TempLogList2;
    IF object_id('TEMPDB.DBO.#TempLog1') IS NOT NULL
        DROP TABLE #TempLog1;
    IF object_id('TEMPDB.DBO.#TempLog1') IS NOT NULL
        DROP TABLE #TempLog2;
 
    CREATE TABLE ##TempLogList1(
        ArchiveNumber INT NOT NULL,
        --LogFromDate DATE NOT NULL,
        LogToDate DATE NOT NULL,
        LogSizeBytes BIGINT NOT NULL);
 
    CREATE TABLE #TempLog1(
        LogDate     DATETIME,
        ProcessInfo VARCHAR(64),
        LogText     VARCHAR(MAX));
 
    CREATE TABLE #TempLog2(
        LogDate     DATETIME,
        ProcessInfo VARCHAR(64),
        LogText     VARCHAR(MAX));
 
    --Get the list of all logs available (current and archived)
    INSERT INTO ##TempLogList1
    EXEC sys.sp_enumerrorlogs;
 
    --LogFromDate is populated here
    SELECT
        ArchiveNumber,
        COALESCE((LEAD(LogToDate) OVER (ORDER BY ArchiveNumber)), '20000101') LogFromDate,
        LogToDate,
        LogSizeBytes
    INTO
        #TempLogList2
    FROM
        ##TempLogList1
    ORDER BY
        LogFromDate, LogToDate;
 
    --Remove archive logs whose date criteria does not fit the parameters
    --....and No, it is not a mistake that the comparison has the two dates interchanged! Just think for a few minutes
    DELETE FROM #TempLogList2
    WHERE LogToDate < COALESCE(@FromDate, '20000101')            OR LogFromDate > COALESCE(@ToDate, '99991231');
 
    --Loop through and get the list
    WHILE 1=1
    BEGIN
        SELECT @ArchiveNumber = MIN(ArchiveNumber)
        FROM #TempLogList2;
 
        IF @ArchiveNumber  IS NULL
          BREAK;
 
        --Insert the error log data into our temp table
        --Read the errorlog data
        /*
        --https://www.mssqltips.com/sqlservertip/1476/reading-the-sql-server-log-files-using-tsql/
        This procedure takes four parameters:
 
        Value of error log file you want to read: 0 = current, 1 = Archive #1, 2 = Archive #2, etc...
        Log file type: 1 or NULL = error log, 2 = SQL Agent log
        Search string 1: String one you want to search for
        Search string 2: String two you want to search for to further refine the results
        */
        INSERT INTO #TempLog1
        EXEC xp_readerrorlog @ArchiveNumber, 1, @SearchString1, @SearchString2, @FromDate, @ToDate, 'ASC'
 
        IF (@SearchShowAdjacentLogsPlusMinus > 0)
            --This is purely to get the adjacent records
            INSERT INTO #TempLog2
            EXEC xp_readerrorlog @ArchiveNumber, 1, NULL, NULL, @FromDate, @ToDate, 'ASC';
 
        --Remove just processed archive number from the list
        DELETE FROM #TempLogList2
        WHERE ArchiveNumber = @ArchiveNumber;
    END;
 
    IF (@SearchShowAdjacentLogsPlusMinus <= 0)
        SELECT * FROM #TempLog1
        ORDER BY LogDate ASC;
    ELSE
    BEGIN
 
        --To give the search text some context, we include the log records adjacent to the ones
        --  that matched the search criteria. For example search string "error" would match
        --  "Error: 1101, Severity: 17, State: 12.". However, to get the context, we need
        --  the adjacent rows that show the specific error which is on another adjacent row:
        --      Could not allocate a new page for database 'MyDb' because of insufficient disk space in filegroup 'PRIMARY'.
        --      Create the necessary space by dropping objects in the filegroup, adding additional files to the filegroup, or setting autogrowth on for existing files in the filegroup.
        WITH t1
        AS
        (
            SELECT *
            FROM #TempLog1
        ),
        t2
        AS
        (
            --Select the previous and next x'TH dates as part of the current row
            SELECT *,
                LAG(LogDate, @SearchShowAdjacentLogsPlusMinus) OVER (ORDER BY LogDate) AS LagLogDate,
                LEAD(LogDate, @SearchShowAdjacentLogsPlusMinus) OVER (ORDER BY LogDate) AS LeadLogDate
            FROM #TempLog2
        )
        SELECT DISTINCT t2.LogDate, t2.ProcessInfo, t2.LogText
        FROM t2
        INNER JOIN t1
            ON t1.LogDate BETWEEN t2.LagLogDate
                AND t2.LeadLogDate
        ORDER BY
            t2.LogDate ASC;
    END;
 
    DROP TABLE #TempLog1;
    DROP TABLE #TempLog2;
    DROP TABLE ##TempLogList1;
    DROP TABLE #TempLogList2;
END;
