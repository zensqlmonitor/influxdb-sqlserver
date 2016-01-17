SET NOCOUNT ON;
SET ARITHABORT ON; 
SET QUOTED_IDENTIFIER ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @ms_ticks bigint;
SET @ms_ticks = (Select ms_ticks From sys.dm_os_sys_info);
DECLARE @maxEvents int = 1

SELECT 
-- measurement
'CPU'
-- tags
+ ',servername=' + REPLACE(@@SERVERNAME, '\', ':') + ''
+ ',type=CPU'
-- value
+ ' SQLProcessUtilization=' + CAST(ProcessUtilization as varchar(8)) 
+ ',ExternalProcessUtilization=' + CAST(100 - SystemIdle - ProcessUtilization as varchar(8)) 
+ ',SystemIdle=' + CAST( SystemIdle as varchar(8)) 
--+ ' ' + CAST(DATEDIFF(SECOND,{d '1970-01-01'}, EventTime) as varchar(32)) 
FROM
(
Select Top (@maxEvents) 
  EventTime = CAST(DateAdd(ms, -1 * (@ms_ticks - timestamp_ms), GetUTCDate()) as datetime)
, ProcessUtilization = CAST(ProcessUtilization as int)
, SystemIdle = CAST(SystemIdle as int)
From (Select Record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') as SystemIdle,
		     Record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') as ProcessUtilization,
		     timestamp as timestamp_ms
From (Select timestamp, convert(xml, record) As Record 
		From sys.dm_os_ring_buffers 
		Where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
		    And record Like '%<SystemHealth>%') x) y 
Order By timestamp_ms Desc
) as T;
