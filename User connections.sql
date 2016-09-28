use master;
go

--sp_who2

select hostname 'Connect User', loginame, db_name(dbid) 'Database', Program_Name, count(Program_Name) 'Connections'
from master master.dbo.sysprocesses 
where hostname = 'computername' and
db_name(id) <> 'master'
group by HostName,db_name(id),Program_Name,loginame
