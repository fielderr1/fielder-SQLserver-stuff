Use master;
go

sp_who2
sp_who2 88

dbcc inputbuffer(88)

--kill 88


--blocking
select * from sys.dm_exec_requests where blocking_session_id <> 0;

select session_id,wait_duration_ms,wait_type,blocking_session_id
from sys.dm_os_waiting_tasks
where blocking_session_id <> 0;


----http://sqlblog.com/blogs/jonathan_kehayias/archive/2010/01/19/tuning-cost-threshold-of-parallelism-from-the-plan-cache.aspx
----cost threshold for Paralellism if cxPacket waits are high

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH XMLNAMESPACES  
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
SELECT 
        query_plan AS CompleteQueryPlan,
        n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS StatementText,
        n.value('(@StatementOptmLevel)[1]', 'VARCHAR(25)') AS StatementOptimizationLevel,
        n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS StatementSubTreeCost,
        n.query('.') AS ParallelSubTreeXML, 
        ecp.usecounts,
        ecp.size_in_bytes
FROM sys.dm_exec_cached_plans AS ecp
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS eqp
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn(n)
WHERE  n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1 


