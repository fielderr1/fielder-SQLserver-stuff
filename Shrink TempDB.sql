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
----if replication this flush old transactions from queue backupset had captured
--execute sp_repldone @xact_sgno = Null, @numtrans = 0, @time = 0, @reset = 1

--Old syntax deprecated post 2k8
DBCC SHRINKFILE (2,1, TRUNCATEONLY)
GO
BACKUP LOG <DataBase_Name>
WITH TRUNCATE_ONLY
GO
DBCC SHRINKFILE (2,1, TRUNCATEONLY)
GO


--new syntax
use master;
go

alter database dbName
set recovery simple;
go

use dbName
go
dbcc shrinkfile (N'dbName_log',0,TruncateOnly);
go

use master
go
alter database dbName
set recovery full;
go


--file path details for dbs
select db.name as 'dbName',mf.name as 'LogicalFileName',mf.physicalname as 'FilePath'
from sys.databases db
inner join sys.master_files mf on db.database_id = mf.database_id
where db.database_id > 4 and
      mf.type_desc = 'Log'
      
--shrink statements for all dbs
declare @SQL varchar (4000);

Select '--dbName ' + char(13) + char(10) +
'use master;'  + char(13) + char(10) +
'go '  + char(13) + char(10) +
'alter database ' + db.name + ' set recovery simple;' + char(13) + char(10) +
'go ' + char(13) + char(10) + char(13) + char(10) +
'use ' db.name + ';' + char(13) + char(10) +
'go '  + char(13) + char(10) +
'chekcpoint; '  + char(13) + char(10) +
 'go '  + char(13) + char(10) +
'chekcpoint; '  + char(13) + char(10) +
'go '  + char(13) + char(10) +
'dbcc shfrinkfile (' + mf.Name + ',1 );' + char(13) + char(10) +
'dbcc shfrinkfile (' + mf.Name + ',1 );' + char(13) + char(10) +
'execute sp_helpdb ' + db.Name + ';' + char(13) + char(10) +
'dbcc shfrinkfile (' + mf.Name + ',1 );' + char(13) + char(10) +
'dbcc shfrinkfile (' + mf.Name + ',1 );' + char(13) + char(10) + char(13) + char(10) +
'use master;'  + char(13) + char(10) +
'go '  + char(13) + char(10) +
'alter database ' + db.name + ' set recovery full;' + char(13) + char(10) +
'go ' + char(13) + char(10) + char(13) + char(10)
from sys.databases db
inner join sys.master_files mf on db.database_id = mf.database_id
where db.database_id > 4
and mf.type_desc = 'Log'
order by db.Name asc;






