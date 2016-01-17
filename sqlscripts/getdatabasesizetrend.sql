SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
IF OBJECT_ID('tempdb..#baseline') IS NOT NULL
	DROP TABLE #baseline;
SELECT 
    DB_NAME(mf.database_id) AS database_name , 
    mf.physical_name , 
    divfs.num_of_reads , 
    divfs.num_of_bytes_read , 
    divfs.io_stall_read_ms , 
    divfs.num_of_writes , 
    divfs.num_of_bytes_written , 
    divfs.io_stall_write_ms , 
    divfs.io_stall , 
    size_on_disk_bytes , 
	type_desc as datafile_type,
    GETDATE() AS baselineDate 
INTO #baseline 
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS divfs 
INNER JOIN sys.master_files AS mf ON mf.database_id = divfs.database_id 
	AND mf.file_id = divfs.file_id

DECLARE @DynamicPivotQuery AS NVARCHAR(MAX)
DECLARE @ColumnName AS NVARCHAR(MAX), @ColumnName2 AS NVARCHAR(MAX)

SELECT @ColumnName= ISNULL(@ColumnName + ',','') + QUOTENAME(database_name)
FROM (SELECT DISTINCT database_name FROM #baseline) AS bl
SELECT @ColumnName2= ISNULL(@ColumnName2+ '+','') + ''',' + database_name + '=''' + + ' + CAST(' + QUOTENAME(database_name) + ' as varchar(16))'
FROM (SELECT DISTINCT database_name FROM #baseline) AS bl
 
--Prepare the PIVOT query using the dynamic 
SET @DynamicPivotQuery = N'
SELECT ''DatabaseSizeTrend'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'')  + '''' + '',type=DatabaseLogSizeTrend''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT database_name, size_on_disk_bytes
FROM #baseline  
WHERE datafile_type = ''LOG''
) as V
PIVOT(SUM(size_on_disk_bytes) FOR database_name IN (' + @ColumnName + ')) AS PVTTable

UNION ALL

SELECT ''DatabaseSizeTrend'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'')  + '''' + '',type=DatabaseRowsSizeTrend''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT database_name, size_on_disk_bytes
FROM #baseline 
WHERE datafile_type = ''ROWS''
) as V
PIVOT(SUM(size_on_disk_bytes) FOR database_name IN (' + @ColumnName + ')) AS PVTTable	
'
--PRINT @DynamicPivotQuery
EXEC sp_executesql @DynamicPivotQuery;
