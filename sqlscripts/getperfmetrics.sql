SET NOCOUNT ON;
SET ARITHABORT ON; 
SET QUOTED_IDENTIFIER ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @PCounters TABLE(
	counter_name nvarchar(64),
	cntr_value bigint,
	Primary Key(counter_name)
);
INSERT @PCounters (counter_name, cntr_value)
SELECT 'PageFileUsagePercent', CAST(100 * (1 - available_page_file_kb * 1. / total_page_file_kb) as decimal(9,2)) as PageFileUsagePercent
FROM sys.dm_os_sys_memory
UNION ALL
SELECT 'ConnectionMemoryBytesPerUserConnection',  Ratio = CAST((cntr_value / (SELECT 1.0 * cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'User Connections')) * 1024 as int)
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Connection Memory (KB)'
UNION ALL
SELECT 'AvailablePhysicalMemoryInBytes', available_physical_memory_kb * 1024 
FROM sys.dm_os_sys_memory
UNION ALL
SELECT 'SignalWaitPercent', SignalWaitPercent = CAST(100.0 * SUM(signal_wait_time_ms) / SUM (wait_time_ms) AS NUMERIC(20,2)) 
FROM sys.dm_os_wait_stats 
UNION ALL
SELECT 'SqlCompilationPercent',  SqlCompilationPercent = 100.0 * cntr_value / (SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec')
FROM sys.dm_os_performance_counters
WHERE counter_name = 'SQL Compilations/sec'
UNION ALL
SELECT 'SqlReCompilationPercent', SqlReCompilationPercent = 100.0 *cntr_value / (SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec')
FROM sys.dm_os_performance_counters
WHERE counter_name = 'SQL Re-Compilations/sec'
UNION ALL
SELECT 'PageLookupPercent',PageLookupPercent = 100.0 * cntr_value / (SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec') 
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page lookups/sec'
UNION ALL
SELECT 'PageSplitPercent',PageSplitPercent = 100.0 * cntr_value / (SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec') 
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page splits/sec'
UNION ALL
SELECT 'AverageTasks', AverageTaskCount = (SELECT AVG(current_tasks_count) FROM sys.dm_os_schedulers WITH (NOLOCK) WHERE scheduler_id < 255 )
UNION ALL
SELECT 'AverageRunnableTasks', AverageRunnableTaskCount = (SELECT AVG(runnable_tasks_count) FROM sys.dm_os_schedulers WITH (NOLOCK) WHERE scheduler_id < 255 )
UNION ALL
SELECT 'AveragePendingDiskIO', AveragePendingDiskIOCount = (SELECT AVG(pending_disk_io_count) FROM sys.dm_os_schedulers WITH (NOLOCK) WHERE scheduler_id < 255 )
UNION ALL
SELECT 'BufferPoolRate', BufferPoolRate = (1.0*cntr_value * 8 * 1024) / 
	(SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters  WHERE object_name like '%Buffer Manager%' AND lower(counter_name) = 'Page life expectancy')
FROM sys.dm_os_performance_counters
WHERE object_name like '%Buffer Manager%'
AND counter_name = 'database pages'
UNION ALL
SELECT 'MemoryGrantPending', MemoryGrantPending = cntr_value 
FROM sys.dm_os_performance_counters 
WHERE counter_name = 'Memory Grants Pending'
UNION ALL
SELECT 'ReadaheadPercent', SqlReCompilationPercent = 100.0 *cntr_value / (SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Page Reads/sec')
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Readahead pages/sec'
UNION ALL
SELECT 'TotalTargetMemoryRatio', TotalTargetMemoryRatio = 100.0 * cntr_value / (SELECT 1.0*cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Target Server Memory (KB)') 
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Total Server Memory (KB)'


IF OBJECT_ID('tempdb..#PCounters') IS NOT NULL DROP TABLE #PCounters;
SELECT * INTO #PCounters FROM @PCounters

DECLARE @DynamicPivotQuery AS NVARCHAR(MAX)
DECLARE @ColumnName AS NVARCHAR(MAX), @ColumnName2 AS NVARCHAR(MAX)
SELECT @ColumnName= ISNULL(@ColumnName + ',','') + QUOTENAME(counter_name)
FROM (SELECT DISTINCT counter_name FROM @PCounters) AS bl
SELECT @ColumnName2= ISNULL(@ColumnName2+ '+','') + ''',' + counter_name + '=''' + + ' + CAST(' + QUOTENAME(counter_name) + ' as varchar(16))'
FROM (SELECT DISTINCT counter_name FROM @PCounters) AS bl
 
SET @DynamicPivotQuery = N'
SELECT ''PerformanceMetrics'' + '',servername='' + REPLACE(@@SERVERNAME, ''\'', '':'')  + '''' + '',type=PerformanceMetrics''
 + '' '' + ' + STUFF(@ColumnName2, 1, 2, '''') + ' FROM
(
SELECT counter_name, cntr_value
FROM #PCounters
) as V
PIVOT(SUM(cntr_value) FOR counter_name IN (' + @ColumnName + ')) AS PVTTable
'
EXEC sp_executesql @DynamicPivotQuery;
