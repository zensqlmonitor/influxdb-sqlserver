SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF OBJECT_ID('tempdb..#PCounters') IS NOT NULL DROP TABLE #PCounters
CREATE TABLE #PCounters
(
	object_name nvarchar(128),
	counter_name nvarchar(128),
	instance_name nvarchar(128),
	cntr_value bigint,
	cntr_type INT,
	Primary Key(object_name, counter_name, instance_name)
);
INSERT #PCounters
SELECT RTrim(spi.object_name) object_name
, RTrim(spi.counter_name) counter_name
, RTrim(spi.instance_name) instance_name
, spi.cntr_value
, spi.cntr_type
FROM sys.dm_os_performance_counters spi
WHERE spi.object_name NOT LIKE 'SQLServer:Backup Device%'
	AND NOT EXISTS (SELECT 1 FROM sys.databases WHERE Name = spi.instance_name);

WAITFOR DELAY '00:00:01';

IF OBJECT_ID('tempdb..#CCounters') IS NOT NULL DROP TABLE #CCounters
CREATE TABLE #CCounters
(
	object_name nvarchar(128),
	counter_name nvarchar(128),
	instance_name nvarchar(128),
	cntr_value bigint,
	cntr_type INT,
	Primary Key(object_name, counter_name, instance_name)
);
INSERT #CCounters
SELECT RTrim(spi.object_name) object_name
, RTrim(spi.counter_name) counter_name
, RTrim(spi.instance_name) instance_name
, spi.cntr_value
, spi.cntr_type
FROM sys.dm_os_performance_counters spi
WHERE spi.object_name NOT LIKE 'SQLServer:Backup Device%'
	AND NOT EXISTS (SELECT 1 FROM sys.databases WHERE Name = spi.instance_name);


-- <measurement>[,<tag-key>=<tag-value>...] <field-key>=<field-value>[,<field2-key>=<field2-value>...] [unix-nano-timestamp]


SELECT 
-- measurement
result = REPLACE(cc.counter_name + CASE WHEN LEN(cc.instance_name) > 0 THEN ' | ' + REPLACE(cc.instance_name, ' ', '\ ') ELSE '' END , ' ', '\ ')
-- tags
+ ',servername=' + REPLACE(@@SERVERNAME, '\', ':') + ''
+ ',objectname="' + REPLACE(cc.object_name, ' ', '') + '"'
-- value
+ ' value=' + CAST(CAST(Case cc.cntr_type
    When 65792 Then cc.cntr_value -- Count
    When 537003264 Then IsNull(Cast(cc.cntr_value as Money) / NullIf(cbc.cntr_value, 0), 0) -- Ratio
    When 272696576 Then cc.cntr_value - pc.cntr_value -- Per Second
    When 1073874176 Then IsNull(Cast(cc.cntr_value - pc.cntr_value as Money) / NullIf(cbc.cntr_value - pbc.cntr_value, 0), 0) -- Avg
    When 1073939712 Then cc.cntr_value - pc.cntr_value -- Base
    Else cc.cntr_value End as bigint) as varchar(19))
--+ ' ' + CAST(DATEDIFF(SECOND,{d '1970-01-01'}, GETDATE()) as varchar(32)) + '000000000' 
FROM #CCounters cc
INNER JOIN #PCounters pc On cc.object_name = pc.object_name
        And cc.counter_name = pc.counter_name
        And cc.instance_name = pc.instance_name
        And cc.cntr_type = pc.cntr_type
LEFT JOIN #CCounters cbc On cc.object_name = cbc.object_name
        And (Case When cc.counter_name Like '%(ms)' Then Replace(cc.counter_name, ' (ms)',' Base')
                  When cc.object_name = 'SQLServer:FileTable' Then Replace(cc.counter_name, 'Avg ','') + ' base'
                  When cc.counter_name = 'Worktables From Cache Ratio' Then 'Worktables From Cache Base'
                  When cc.counter_name = 'Avg. Length of Batched Writes' Then 'Avg. Length of Batched Writes BS'
                  Else cc.counter_name + ' base' 
             End) = cbc.counter_name
        And cc.instance_name = cbc.instance_name
        And cc.cntr_type In (537003264, 1073874176)
        And cbc.cntr_type = 1073939712
LEFT JOIN #PCounters pbc On pc.object_name = pbc.object_name
        And pc.instance_name = pbc.instance_name
        And (Case When pc.counter_name Like '%(ms)' Then Replace(pc.counter_name, ' (ms)',' Base')
                  When pc.object_name = 'SQLServer:FileTable' Then Replace(pc.counter_name, 'Avg ','') + ' base'
                  When pc.counter_name = 'Worktables From Cache Ratio' Then 'Worktables From Cache Base'
                  When pc.counter_name = 'Avg. Length of Batched Writes' Then 'Avg. Length of Batched Writes BS'
                  Else pc.counter_name + ' base' 
             End) = pbc.counter_name
        And pc.cntr_type In (537003264, 1073874176)
        And pbc.cntr_type = 1073939712
--WHERE cc.counter_name LIKE 'Batch Requests/sec'
ORDER BY 1
IF OBJECT_ID('tempdb..#CCounters') IS NOT NULL DROP TABLE #CCounters;
IF OBJECT_ID('tempdb..#PCounters') IS NOT NULL DROP TABLE #PCounters;

