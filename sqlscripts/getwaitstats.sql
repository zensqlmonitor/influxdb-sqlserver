SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE @secondsBetween tinyint = 15
DECLARE @delayInterval char(8) = CONVERT(Char(8), DATEADD(SECOND, @secondsBetween, '00:00:00'), 108);
DECLARE @w1 TABLE 
(
	WaitType varchar(64) NOT NULL, 
	WaitTimeInMs bigint NOT NULL, 
	WaitTaskCount bigint NOT NULL,
	CollectionDate datetime NOT NULL
)
DECLARE @w2 TABLE 
(
	WaitType varchar(64) NOT NULL, 
	WaitTimeInMs bigint NOT NULL, 
	WaitTaskCount bigint NOT NULL,
	CollectionDate datetime NOT NULL
)
INSERT @w1 (WaitType, WaitTimeInMs, WaitTaskCount, CollectionDate)
SELECT
  WaitType = wait_type
, WaitTimeInMs = SUM(wait_time_ms) 
, WaitTaskCount = SUM(waiting_tasks_count)
, CollectionDate = GETDATE()
FROM sys.dm_os_wait_stats
WHERE [wait_type] NOT IN (
    N'QDS_SHUTDOWN_QUEUE', 
	N'BROKER_EVENTHANDLER',             N'BROKER_RECEIVE_WAITFOR',
	N'BROKER_TASK_STOP',                N'BROKER_TO_FLUSH',
	N'BROKER_TRANSMITTER',              N'CHECKPOINT_QUEUE',
	N'CHKPT',                           N'CLR_AUTO_EVENT',
	N'CLR_MANUAL_EVENT',                N'CLR_SEMAPHORE',
	N'DBMIRROR_DBM_EVENT',              N'DBMIRROR_EVENTS_QUEUE',
	N'DBMIRROR_WORKER_QUEUE',           N'DBMIRRORING_CMD',
	N'DIRTY_PAGE_POLL',                 N'DISPATCHER_QUEUE_SEMAPHORE',
	N'EXECSYNC',                        N'FSAGENT',
	N'FT_IFTS_SCHEDULER_IDLE_WAIT',     N'FT_IFTSHC_MUTEX',
	N'HADR_CLUSAPI_CALL',               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
	N'HADR_LOGCAPTURE_WAIT',            N'HADR_NOTIFICATION_DEQUEUE',
	N'HADR_TIMER_TASK',                 N'HADR_WORK_QUEUE',
	N'KSOURCE_WAKEUP',                  N'LAZYWRITER_SLEEP',
	N'LOGMGR_QUEUE',                    N'ONDEMAND_TASK_QUEUE',
	N'PWAIT_ALL_COMPONENTS_INITIALIZED',
	N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
	N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
	N'REQUEST_FOR_DEADLOCK_SEARCH',     N'RESOURCE_QUEUE',
	N'SERVER_IDLE_CHECK',               N'SLEEP_BPOOL_FLUSH',
	N'SLEEP_DBSTARTUP',                 N'SLEEP_DCOMSTARTUP',
	N'SLEEP_MASTERDBREADY',             N'SLEEP_MASTERMDREADY',
	N'SLEEP_MASTERUPGRADED',            N'SLEEP_MSDBSTARTUP',
	N'SLEEP_SYSTEMTASK',                N'SLEEP_TASK',
	N'SLEEP_TEMPDBSTARTUP',             N'SNI_HTTP_ACCEPT',
	N'SP_SERVER_DIAGNOSTICS_SLEEP',     N'SQLTRACE_BUFFER_FLUSH',
	N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
	N'SQLTRACE_WAIT_ENTRIES',           N'WAIT_FOR_RESULTS',
	N'WAITFOR',                         N'WAITFOR_TASKSHUTDOWN',
	N'WAIT_XTP_HOST_WAIT',              N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
	N'WAIT_XTP_CKPT_CLOSE',             N'XE_DISPATCHER_JOIN',
	N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT')
AND [waiting_tasks_count] > 0
GROUP BY wait_type
 
WAITFOR DELAY @delayInterval;

INSERT @w2 (WaitType, WaitTimeInMs, WaitTaskCount, CollectionDate)
SELECT
  WaitType = wait_type
, WaitTimeInMs = SUM(wait_time_ms) 
, WaitTaskCount = SUM(waiting_tasks_count)
, CollectionDate = GETDATE()
FROM sys.dm_os_wait_stats
WHERE [wait_type] NOT IN (
	N'BROKER_EVENTHANDLER',             N'BROKER_RECEIVE_WAITFOR',
	N'BROKER_TASK_STOP',                N'BROKER_TO_FLUSH',
	N'BROKER_TRANSMITTER',              N'CHECKPOINT_QUEUE',
	N'CHKPT',                           N'CLR_AUTO_EVENT',
	N'CLR_MANUAL_EVENT',                N'CLR_SEMAPHORE',
	N'DBMIRROR_DBM_EVENT',              N'DBMIRROR_EVENTS_QUEUE',
	N'DBMIRROR_WORKER_QUEUE',           N'DBMIRRORING_CMD',
	N'DIRTY_PAGE_POLL',                 N'DISPATCHER_QUEUE_SEMAPHORE',
	N'EXECSYNC',                        N'FSAGENT',
	N'FT_IFTS_SCHEDULER_IDLE_WAIT',     N'FT_IFTSHC_MUTEX',
	N'HADR_CLUSAPI_CALL',               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
	N'HADR_LOGCAPTURE_WAIT',            N'HADR_NOTIFICATION_DEQUEUE',
	N'HADR_TIMER_TASK',                 N'HADR_WORK_QUEUE',
	N'KSOURCE_WAKEUP',                  N'LAZYWRITER_SLEEP',
	N'LOGMGR_QUEUE',                    N'ONDEMAND_TASK_QUEUE',
	N'PWAIT_ALL_COMPONENTS_INITIALIZED',
	N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
	N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
	N'REQUEST_FOR_DEADLOCK_SEARCH',     N'RESOURCE_QUEUE',
	N'SERVER_IDLE_CHECK',               N'SLEEP_BPOOL_FLUSH',
	N'SLEEP_DBSTARTUP',                 N'SLEEP_DCOMSTARTUP',
	N'SLEEP_MASTERDBREADY',             N'SLEEP_MASTERMDREADY',
	N'SLEEP_MASTERUPGRADED',            N'SLEEP_MSDBSTARTUP',
	N'SLEEP_SYSTEMTASK',                N'SLEEP_TASK',
	N'SLEEP_TEMPDBSTARTUP',             N'SNI_HTTP_ACCEPT',
	N'SP_SERVER_DIAGNOSTICS_SLEEP',     N'SQLTRACE_BUFFER_FLUSH',
	N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
	N'SQLTRACE_WAIT_ENTRIES',           N'WAIT_FOR_RESULTS',
	N'WAITFOR',                         N'WAITFOR_TASKSHUTDOWN',
	N'WAIT_XTP_HOST_WAIT',              N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
	N'WAIT_XTP_CKPT_CLOSE',             N'XE_DISPATCHER_JOIN',
	N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT')
AND [waiting_tasks_count] > 0
GROUP BY wait_type

SELECT 
-- measurement
   T1.WaitType
-- tags
+ ',servername=' + REPLACE(@@SERVERNAME, '\', ':') + ''
+ ',type=WaitStats'
-- value
+ ' waittimeinms=' + CAST(T2.WaitTimeInMs - T1.WaitTimeInMs as varchar(16))
+ ',waittaskcount=' + CAST(T2.WaitTaskCount - T1.WaitTaskCount as varchar(16))
+ ',waittimeinmspersec=' + CAST((T2.WaitTimeInMs - T1.WaitTimeInMs) / CAST(DATEDIFF(SECOND, T1.CollectionDate, T2.CollectionDate) as float) as varchar(16))
FROM @w1 T1 
INNER JOIN @w2 T2 ON T2.WaitType = T1.WaitType
WHERE T2.WaitTaskCount - T1.WaitTaskCount > 0;
