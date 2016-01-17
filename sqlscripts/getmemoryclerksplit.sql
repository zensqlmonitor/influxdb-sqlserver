SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @w TABLE (ClerkCategory nvarchar(64) NOT NULL, UsedPercent decimal(9,2), UsedBytes bigint)
INSERT  @w (ClerkCategory, UsedPercent, UsedBytes)
SELECT ClerkCategory
, UsedPercent = SUM(UsedPercent)
, UsedBytes = SUM(UsedBytes)
FROM
( 
SELECT ClerkCategory = CASE MC.[type]
	WHEN 'MEMORYCLERK_SQLBUFFERPOOL' THEN 'Buffer Pool'
	WHEN 'CACHESTORE_SQLCP' THEN 'Cache (sql plans)'
	WHEN 'CACHESTORE_OBJCP' THEN 'Cache (objects)'
	ELSE 'Other' END
, SUM(pages_kb * 1024) AS UsedBytes
, Cast(100 * Sum(pages_kb)*1.0/(Select Sum(pages_kb) From sys.dm_os_memory_clerks) as Decimal(7, 4)) UsedPercent
FROM sys.dm_os_memory_clerks MC
WHERE pages_kb > 0
GROUP BY CASE MC.[type]
	WHEN 'MEMORYCLERK_SQLBUFFERPOOL' THEN 'Buffer Pool'
	WHEN 'CACHESTORE_SQLCP' THEN 'Cache (sql plans)'
	WHEN 'CACHESTORE_OBJCP' THEN 'Cache (objects)'
	ELSE 'Other' END
) as T
GROUP BY ClerkCategory

SELECT 
-- measurement
Measurement
-- tags
+ ',servername=' + REPLACE(@@SERVERNAME, '\', ':') + ''
+ ',type=MemoryClerk'
-- value
+ ' BufferPool=' + [Buffer Pool]
+ ',Cache(objects)=' + [Cache (objects)]
+ ',Cache(sqlplans)=' + [Cache (sql plans)]
+ ',Other=' + [Other]
FROM
(
SELECT Measurement = 'UsedPercent'
, [Buffer Pool] = CAST(ISNULL(ROUND([Buffer Pool], 1), 0) as varchar(16))
, [Cache (objects)] = CAST(ISNULL(ROUND([Cache (objects)], 1), 0) as varchar(16))
, [Cache (sql plans)] = CAST(ISNULL(ROUND([Cache (sql plans)], 1), 0) as varchar(16))
, [Other] = CAST(ISNULL(ROUND([Other], 1), 0) as varchar(16))
FROM (SELECT ClerkCategory, UsedPercent FROM @w) as G1
PIVOT
(
	SUM(UsedPercent)
	FOR ClerkCategory IN ([Buffer Pool], [Cache (objects)], [Cache (sql plans)], [Other])
) AS PivotTable

UNION ALL

SELECT 'UsedBytes'
, [Buffer Pool] = CAST(ISNULL(ROUND([Buffer Pool], 1), 0) as varchar(16))
, [Cache (objects)] = CAST(ISNULL(ROUND([Cache (objects)], 1), 0) as varchar(16))
, [Cache (sql plans)] = CAST(ISNULL(ROUND([Cache (sql plans)], 1), 0) as varchar(16))
, [Other] = CAST(ISNULL(ROUND([Other], 1), 0) as varchar(16))
FROM (SELECT ClerkCategory, UsedBytes FROM @w) as G2 
PIVOT
(
	SUM(UsedBytes)
	FOR ClerkCategory IN ([Buffer Pool], [Cache (objects)], [Cache (sql plans)], [Other])
) AS PivotTable
) as T;
