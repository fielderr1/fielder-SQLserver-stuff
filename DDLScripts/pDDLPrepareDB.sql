use master;
go

if object_id('pDDLPrepareRunUnitTest') is not null
	drop procedure dbo.pDDLPrepareRunUnitTest;
go

set quoted_identifier on;
go

set ansi_nulls on;
go  

/**********************************************************************************  
-- Stored Procedure  dbo.pDDLPrepareRunUnitTest 
-- Author    RSF   
-- Date     2012-01-18
-- Description   Creates DB
-- Change Hisory    
--
-- execute pDDLPrepareRunUnitTest 'UnitTest'
**********************************************************************************/  

create procedure dbo.pDDLPrepareRunUnitTest
(
			@ipDBName sysname
)

as

begin

set nocount on;
set transaction isolation level read uncommitted;
  
declare @SQLdropdb varchar(32),@SQLcreatedb varchar(512),@lvErrorCnt int,@lvErrorMsg varchar(2000);

	if exists(select 1 from master.dbo.sysdatabases where dbid > 6 and name = @ipDBName)
	begin
		--1.0  Kill all DB Conections for db delete
		declare @spid int, @cnt int, @sql varchar(255);
		
		select @spid = min(spid),@cnt = count(*) 
		from master..sysprocesses 
		where [dbid] = db_id(@ipDBName) and
			  spid != @@spid;

		while @spid is not null 
			begin 
				set @sql = 'kill ' + rtrim(@spid) 
				execute(@sql) 
				select @spid = min(spid),@cnt = count(*) 
				from master..sysprocesses 
				where dbid = db_id(@ipDBName) and spid != @@spid 
			end;

		--1.1  Drop UnitTest db
		set @SQLdropdb = ''
		set @SQLdropdb = @SQLdropdb + 'drop database ' + @ipDBName
		execute(@SQLdropdb);
		
		if @@error <> 0 or @@rowcount = 0
		begin
			set @lvErrorMsg = 'Could not drop database' + @ipDBName
			goto SQLError
		end
	end


	--2.0  Create UnitTest db
	set @SQLcreatedb = ''
	set @SQLcreatedb = @SQLcreatedb + 'create database ' + @ipDBName + ' on primary ('
	set @SQLcreatedb = @SQLcreatedb + 'Name = ' + @ipDBName + '_dat,'
	set @SQLcreatedb = @SQLcreatedb + 'Filename = ''D:\Program Files (x86)\Microsoft SQL Server\MSSQL$SQL2K\data\' + @ipDBName + '_dat.mdf''' + ','
	set @SQLcreatedb = @SQLcreatedb + 'Size = 1000MB,Filegrowth = 2%)'
	set @SQLcreatedb = @SQLcreatedb + 'LOG ON ('
	set @SQLcreatedb = @SQLcreatedb + 'Name = ' + @ipDBName + '_log,'
	set @SQLcreatedb = @SQLcreatedb + 'Filename = ''D:\Program Files (x86)\Microsoft SQL Server\MSSQL$SQL2K\data\' + @ipDBName + '_log.ldf''' + ','
	set @SQLcreatedb = @SQLcreatedb + 'Size = 100MB,Filegrowth = 2%)'
	execute(@SQLcreatedb);
	
	if @@error <> 0 or @@rowcount = 0
	begin
		set @lvErrorMsg = 'Create database ' + @ipDBName + 'failure'
		goto SQLError
	end
	
	--2.1  Change DB owner to SA
	execute UnitTest.dbo.sp_changedbowner 'sa';
 
	declare @SQLcommand varchar(1024) 
	set @SQLcommand = ''
	set @SQLcommand = @SQLcommand + 'execute '
	set @SQLcommand = @SQLcommand + @ipDBName + '.'
	set @SQLcommand = @SQLcommand + ' dbo.sp_changedbowner'
	set @SQLcommand = @SQLcommand + ' sa'
	
	execute(@SQLcommand);
	

/*<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
SQLError:
    if @@trancount > 0
        begin 
            rollback transaction
        end
    raiserror (@lvErrorMsg, 7, -1)
    return (-1)
end;
go
