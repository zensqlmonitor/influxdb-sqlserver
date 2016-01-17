SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT 
-- measurement
'PhysicalMemory'
-- tags
+ ',servername=' + REPLACE(@@SERVERNAME, '\', ':') + ''
+ ',type=Memory'
-- value
+ ' TotalMemory=' + CAST(TotalMemory as varchar(16))
+ ',AvailableMemory=' + CAST(AvailableMemory as varchar(16))
FROM
(
SELECT 
  TotalMemory = total_physical_memory_kb * 1024
, AvailableMemory = available_physical_memory_kb * 1024
FROM sys.dm_os_sys_memory
) as T;