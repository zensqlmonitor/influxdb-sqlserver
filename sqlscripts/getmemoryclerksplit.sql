SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @sqlVers numeric(4,2)
SELECT @sqlVers = LEFT(CAST(SERVERPROPERTY('productversion') as varchar), 4)
IF OBJECT_ID('tempdb..#MemoryClerk') IS NOT NULL
	DROP TABLE #MemoryClerk;
CREATE TABLE #MemoryClerk (
    ClerkCategory nvarchar(64) NOT NULL, 
    UsedPercent decimal(9,2) NOT NULL, 
    UsedBytes bigint NOT NULL
);
DECLARE @DynamicClerkQuery AS NVARCHAR(MAX)
IF @sqlVers < 11
BEGIN
    SET @DynamicClerkQuery = N'
    INSERT #MemoryClerk (ClerkCategory, UsedPercent, UsedBytes)
    SELECT ClerkCategory
    , UsedPercent = SUM(UsedPercent)
    , UsedBytes = SUM(UsedBytes)
    FROM
    (
    SELECT ClerkCategory = CASE MC.[type]
        WHEN ''MEMORYCLERK_SQLBUFFERPOOL'' THEN ''Buffer pool''
        WHEN ''CACHESTORE_SQLCP'' THEN ''Cache (sql plans)''
        WHEN ''CACHESTORE_OBJCP'' THEN ''Cache (objects)''
        ELSE ''Other'' END
    , SUM((single_pages_kb + multi_pages_kb) * 1024) AS UsedBytes
    , Cast(100 * Sum((single_pages_kb + multi_pages_kb))*1.0/(Select Sum((single_pages_kb + multi_pages_kb)) From sys.dm_os_memory_clerks) as Decimal(7, 4)) UsedPercent
    FROM sys.dm_os_memory_clerks MC
    WHERE (single_pages_kb + multi_pages_kb) > 0
    GROUP BY CASE MC.[type]
        WHEN ''MEMORYCLERK_SQLBUFFERPOOL'' THEN ''Buffer pool''
        WHEN ''CACHESTORE_SQLCP'' THEN ''Cache (sql plans)''
        WHEN ''CACHESTORE_OBJCP'' THEN ''Cache (objects)''
        ELSE ''Other'' END
    ) as T
    GROUP BY ClerkCategory;'
END
ELSE
BEGIN
    SET @DynamicClerkQuery = N'
    INSERT #MemoryClerk (ClerkCategory, UsedPercent, UsedBytes)
    SELECT ClerkCategory
    , UsedPercent = SUM(UsedPercent)
    , UsedBytes = SUM(UsedBytes)
    FROM
    (
    SELECT ClerkCategory = CASE MC.[type]
        WHEN ''MEMORYCLERK_SQLBUFFERPOOL'' THEN ''Buffer pool''
        WHEN ''CACHESTORE_SQLCP'' THEN ''Cache (sql plans)''
        WHEN ''CACHESTORE_OBJCP'' THEN ''Cache (objects)''
        ELSE ''Other'' END
    , SUM(pages_kb * 1024) AS UsedBytes
    , Cast(100 * Sum(pages_kb)*1.0/(Select Sum(pages_kb) From sys.dm_os_memory_clerks) as Decimal(7, 4)) UsedPercent
    FROM sys.dm_os_memory_clerks MC
    WHERE pages_kb > 0
    GROUP BY CASE MC.[type]
        WHEN ''MEMORYCLERK_SQLBUFFERPOOL'' THEN ''Buffer pool''
        WHEN ''CACHESTORE_SQLCP'' THEN ''Cache (sql plans)''
        WHEN ''CACHESTORE_OBJCP'' THEN ''Cache (objects)''
        ELSE ''Other'' END
    ) as T
    GROUP BY ClerkCategory;'
END
EXEC sp_executesql @DynamicClerkQuery;

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
FROM (SELECT ClerkCategory, UsedPercent FROM #MemoryClerk) as G1
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
FROM (SELECT ClerkCategory, UsedBytes FROM #MemoryClerk) as G2 
PIVOT
(
	SUM(UsedBytes)
	FOR ClerkCategory IN ([Buffer Pool], [Cache (objects)], [Cache (sql plans)], [Other])
) AS PivotTable
) as T

IF OBJECT_ID('tempdb..#MemoryClerk') IS NOT NULL
	DROP TABLE #MemoryClerk;
 