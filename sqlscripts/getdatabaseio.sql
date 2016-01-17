SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE @secondsBetween tinyint = 5;
DECLARE @delayInterval char(8) = CONVERT(Char(8), DATEADD(SECOND, @secondsBetween, '00:00:00'), 108);

IF OBJECT_ID('tempdb..#baseline') IS NOT NULL
	DROP TABLE #baseline;
IF OBJECT_ID('tempdb..#baselinewritten') IS NOT NULL
	DROP TABLE #baselinewritten;

SELECT DB_NAME(mf.database_id) AS databaseName , 
    mf.physical_name , 
    divfs.num_of_reads , 
    divfs.num_of_bytes_read , 
    divfs.io_stall_read_ms , 
    divfs.num_of_writes , 
    divfs.num_of_bytes_written , 
    divfs.io_stall_write_ms , 
    divfs.io_stall , 
    size_on_disk_bytes , 
    GETDATE() AS baselineDate 
INTO #baseline 
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS divfs 
INNER JOIN sys.master_files AS mf ON mf.database_id = divfs.database_id 
	AND mf.file_id = divfs.file_id

WAITFOR DELAY @delayInterval;

;WITH currentLine AS 
( 
SELECT DB_NAME(mf.database_id) AS databaseName ,
    mf.physical_name , 
	type_desc,
    num_of_reads , 
    num_of_bytes_read , 
    io_stall_read_ms , 
    num_of_writes , 
    num_of_bytes_written , 
    io_stall_write_ms , 
    io_stall , 
    size_on_disk_bytes , 
    GETDATE() AS currentlineDate 
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS divfs 
INNER JOIN sys.master_files AS mf ON mf.database_id = divfs.database_id 
        AND mf.file_id = divfs.file_id 
) 

SELECT database_name
, datafile_type 
, num_of_bytes_read_persec = SUM(num_of_bytes_read_persec)
, num_of_bytes_written_persec = SUM(num_of_bytes_written_persec)
INTO #baselinewritten
FROM
(
SELECT 
	database_name = currentLine.databaseName 
, datafile_type = type_desc
, num_of_bytes_read_persec = (currentLine.num_of_bytes_read - T1.num_of_bytes_read) / (1 * DATEDIFF(SECOND,baseLineDate,currentLineDate))  
, num_of_bytes_written_persec = (currentLine.num_of_bytes_written - T1.num_of_bytes_written) / (1 * DATEDIFF(SECOND,baseLineDate,currentLineDate))  
FROM currentLine 
INNER JOIN #baseline T1 ON T1.databaseName = currentLine.databaseName 
	AND T1.physical_name = currentLine.physical_name
) as T
GROUP BY database_name, datafile_type


DECLARE @DynamicPivotQuery AS NVARCHAR(MAX)
DECLARE @ColumnName AS NVARCHAR(MAX), @ColumnName2 AS NVARCHAR(MAX)

SELECT @ColumnName= ISNULL(@ColumnName + ',','') + QUOTENAME(database_name)
FROM (SELECT DISTINCT database_name FROM #baselinewritten) AS bl
SELECT @ColumnName2= ISNULL(@ColumnName2+ '+','') + ''',' + database_name + '=''' + + ' + CAST(' + QUOTENAME(database_name) + ' as varchar(16))'
FROM (SELECT DISTINCT database_name FROM #baselinewritten) AS bl
 
--Prepare the PIVOT query using the dynamic 
SET @DynamicPivotQuery = N'
SELECT ''DatabaseIO'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'')  + '''' + '',type=DatabaseLogBytesWritten''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT database_name, num_of_bytes_written_persec
FROM #baselinewritten  
WHERE datafile_type = ''LOG''
) as V
PIVOT(SUM(num_of_bytes_written_persec) FOR database_name IN (' + @ColumnName + ')) AS PVTTable

UNION ALL

SELECT ''DatabaseIO'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'') + '''' + '',type=DatabaseRowsBytesWritten''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT database_name, num_of_bytes_written_persec
FROM #baselinewritten  
WHERE datafile_type = ''ROWS''
) as V
PIVOT(SUM(num_of_bytes_written_persec) FOR database_name IN (' + @ColumnName + ')) AS PVTTable	

UNION ALL

SELECT ''DatabaseIO'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'')  + '''' + '',type=DatabaseLogBytesRead''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT database_name, num_of_bytes_read_persec
FROM #baselinewritten  
WHERE datafile_type = ''LOG''
) as V
PIVOT(SUM(num_of_bytes_read_persec) FOR database_name IN (' + @ColumnName + ')) AS PVTTable	

UNION ALL

SELECT ''DatabaseIO'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'')  + '''' + '',type=DatabaseRowsBytesRead''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT database_name, num_of_bytes_read_persec
FROM #baselinewritten  
WHERE datafile_type = ''ROWS''
) as V
PIVOT(SUM(num_of_bytes_read_persec) FOR database_name IN (' + @ColumnName + ')) AS PVTTable	
'
--PRINT @DynamicPivotQuery
EXEC sp_executesql @DynamicPivotQuery;
