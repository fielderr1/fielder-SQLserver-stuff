use TempDB;
go

execute sp_helpdb tempdb;

checkpoint;
go
dbcc DropCleanBuffer;
go
dbcc FreeProcCache;
go
dbcc FreeSystemCache;
go
dbcc ShrinkDatabase(tempdb,10);
go
dbcc ShrinkFile(TempDev, 20480);
go
dbcc ShrinkFile(TempLog, 20480);
go

execute sp_helpdb tempdb;

----if log refuses to shrink
--select log_reuse_wait_desc, is_cdc_enabled, is_broker_enabled, is_published,is_subscribed,is_merge_published, is_distributor, * from sys.databases
----if replication this flush old transactions from queue backupset had camptured
--execute sp_repldone @xact_sgno = Null, @numtrans = 0, @time = 0, @reset = 1

use master;
go

alter database IGT_Wy
set recovery simple;
go

use IBT_WY
go
dbcc shrinkfile (N'IGT_WY_log',0,TruncateOnly);
go

use master
go
alter database IGT_Wy
set recovery full;
go


