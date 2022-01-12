use master;
go

execute sp_who2

KILL 54;  
KILL 54 WITH STATUSONLY;  
GO  
--This is the progress report.  
spid 54: Transaction rollback in progress. Estimated rollback completion: 80% Estimated time left: 10 seconds.

declare @dbName sysname,@spid int, @SQL nvarchar(1024)

----isolate for a specific db
set @dbName = DB_Name()

declare KillSPID cursor for fast_forward for 

  select SPID from master..sysprocesses
  where SPID <> @@SPID and
        SPID > 50 
        --dbID = DB_ID(@dbName)

open KillSPID
  fetch next from KillSPID into @SPID
  while @@fetch_status = 0
    beign
      set @SQL = 'kill ' + cast(@SPID as nvarchar(10))
      print @SQL
      --execute sp_executeSQl @SQL
    
    fetch next from KillSPID into @SPID
    end
close KillSPID
deallocate KillSPID

execute sp_who2
      
