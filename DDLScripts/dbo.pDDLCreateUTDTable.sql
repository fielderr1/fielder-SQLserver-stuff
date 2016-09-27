if object_id('pDDLCreateUTDTable') is not null
	drop procedure pDDLCreateUTDTable
go

create procedure dbo.pDDLCreateUTDTable
			@ipTableName sysname							

as

/**********************************************************************************  
-- Stored Procedure  dbo.pDDLCreateUTDTable 
-- Author    RSF   
-- Date     2011-10-05  
-- Description   Creates ATI UTD script will all default inputs
-- Change Hisory    
--  
--
**********************************************************************************/  
begin

set quoted_identifier on;
set ansi_nulls on;
set nocount on;
set transaction isolation level read uncommitted;  

--Create local variables and assign defaults
declare @lvErrorMsg varchar(256),@lvUTDName sysname,@lvCNT int,@lvCreationDate varchar(10);

Select	@lvErrorMsg = '',
		@lvUTDName = @ipTableName,
		@lvCNT = 0,
		@lvCreationDate = cast(Year(getdate()) as varchar(4)) + '-' + Cast(Month(getdate()) as varchar(02)) + '-' +  cast(Day(getdate()) as varchar(2));

--Test input parameter
if not exists(select 1 from sysobjects where name=@ipTableName and xtype = 'U')
begin
	set @lvErrorMsg='ERROR pDDLCreateUTDTable - Input Table: ' +  @ipTableName + ' does not exist in catalogue unable to create UTD proc!'
	goto SQLerror;
end

--Create properly formated name for UTD proc
select @lvCNT = patindex('%[_]%',@lvUTDName);

while @lvCNT > 0
begin
	Select @lvUTDName = stuff(@lvUTDName,@lvCNT,len(@lvUTDName),substring(@lvUTDName,@lvCNT+1,len(@lvUTDName)))
	select @lvCNT = patindex('%[_]%',@lvUTDName)
end;
set @lvUTDName = 'utd_' + @lvUTDName;

--Ensure that UTD doesn't already exist
if exists(select 1 from sysobjects where name=@lvUTDName and xtype = 'P')
begin
	set @lvErrorMsg='ERROR pDDLCreateUTDTable - PROC: ' +  @lvUTDName + ' already exists in catalogue investigate!'
	goto SQLerror;
end;

--Get the primarykey to build UTD input parameters
Declare @lvPKName varchar(1024),@lvPKinsert varchar(1024), @lvPKcnt int,@lvPKMaxPosition int;

select	@lvPKcnt = 1,
		@lvPKName = '',
		@lvPKinsert = '',
		@lvPKMaxPosition = max(ku.Ordinal_position)
from information_schema.table_constraints tc
inner join information_schema.key_column_usage ku
  on tc.constraint_type = 'primary key' and tc.constraint_name = ku.constraint_name
where ku.table_name = @ipTableName

if @lvPKMaxPosition > 4
begin
	set @lvErrorMsg='ERROR pDDLCreateUTDTable - Table: ' +  @lvUTDName + ' has a composite primary key across more than 4 columns!'
	goto SQLerror;
end;
else
begin
	select @lvPKName = @lvPKName + '	@i'+ ku.Column_Name + ' ' + cl.Data_type + 
				case cl.Data_type
					when 'numeric' then '(' + cast(cl.numeric_precision as varchar(3)) + ',' + cast(cl.numeric_scale as varchar(3)) +')'
					when 'money' then '(' + cast(cl.numeric_precision as varchar(3)) + ',' + cast(cl.numeric_scale as varchar(3)) +')'
					when 'float' then '(' + cast(cl.numeric_precision as varchar(3)) + ',' + cast(cl.numeric_scale as varchar(3)) +')'
					when 'varchar' then '(' + isnull(cast(Character_Maximum_Length as varchar(6)),'') + ')'
					when 'char' then '(' + isnull(cast(Character_Maximum_Length as varchar(6)),'') + ')'
					else isnull(cast(Character_Maximum_Length as varchar(6)),'')
				end
				 + case when cl.ordinal_position <> cast(@lvPKMaxPosition as varchar(12)) then ',' + CHAR(13) else '' end,
			@lvPKinsert = @lvPKinsert + '@i' + ku.Column_Name + ','
	from information_schema.table_constraints tc
	inner join information_schema.key_column_usage ku
	  on tc.constraint_type = 'primary key' and tc.constraint_name = ku.constraint_name
	inner join information_schema.columns cl
	  on ku.Column_Name = cl.Column_Name and ku.table_name = cl.table_name 
	where ku.table_name = @ipTableName 
	order by cl.ordinal_position
	--select @lvPKName = left(@lvPKName, len(@lvPKName)-1)
end

--Create assign variables to build UTD statement
declare @lvMaxOrdinal int, @sqlColumns varchar(4000), @sqlDefault varchar(4000)

select @sqlColumns = '',@sqlDefault =''

select @lvMaxOrdinal = max(Ordinal_Position)
from information_schema.columns
where Table_Name = @ipTableName and Column_Name <> 'RowVersion'

--Insert column list
select @sqlColumns = @sqlColumns + '	' + Column_Name + case when ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) then ',' + CHAR(13) else '' end
from information_schema.columns
where Table_Name = @ipTableName and Column_Name <> 'RowVersion'
order by Ordinal_Position

--Default column list
select @sqlDefault = @sqlDefault + case when Is_Nullable = 'yes' then '	NULL  ' + Column_Name + case when ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) then ','  + CHAR(13) else '' end
						Else case Data_Type
						WHEN 'bit' then '	0  '
						WHEN 'binary' then '	0  '
						WHEN 'int' then '	0  '
						WHEN 'tinyint' then '	0  '
						WHEN 'smallint' then '	0  '
						WHEN 'bigint' then '	0  '
						WHEN 'numeric' then '	0.00  '
						WHEN 'money' then '	0.00  '
						WHEN 'char' then '	''N''  '
						WHEN 'real' then '	0  '
						WHEN 'varchar' then  '	''N''  '
						WHEN 'datetime' then '	''2000-01-01 23:59:59.997''  '
						WHEN 'smalldatetime' then '	''2000-01-01 00:00:00.000''  '
						WHEN 'float' THEN '	0.00  '
					END + Column_name + case when ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) then ',' + CHAR(13) else '' end
				end
 from information_schema.columns 
where table_name = @ipTableName and Column_Name not in (
																select cl.Column_Name
																from information_schema.table_constraints tc
																inner join information_schema.key_column_usage ku
																  on tc.constraint_type = 'primary key' and tc.constraint_name = ku.constraint_name
																left join information_schema.columns cl
																  on ku.Column_Name = cl.Column_Name and ku.table_name = cl.table_name
																where ku.table_name = @ipTableName
																union select 'RowVersion'
															)
order by Ordinal_Position

Print '--	' + @lvUTDName
Print 'IF OBJECT_ID(''' + @lvUTDName + ''') IS NOT NULL'
Print '	DROP PROCEDURE dbo.'  + @lvUTDName
Print 'GO'
Print '' 
Print '/*************************************************************************************
Product: tSQLUnit
Purpose: DB Unit Test

DATE        VERSION         AUTHOR                TRACKER/PROJECT'
Print @lvCreationDate + '	11.6.2			Robert Fielder
Initial Creation


--Test Me'
Print 'EXEC dbo.' + @lvUTDName
Print ''
Print 'ROLLBACK TRAN
*************************************************************************************/'
Print ''
Print 'CREATE PROCEDURE dbo.' + @lvUTDName
Print '('
--select @lvPKName = left(@lvPKName, len(@lvPKName)-2)
Print @lvPKName
Print ')'
Print ''
Print 'AS

BEGIN

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;'
Print ''
IF ((SELECT OBJECTPROPERTY( OBJECT_ID(@ipTableName), 'TableHasIdentity')) = 1)
begin
Print 'SET IDENTITY_INSERT dbo.' + @ipTableName + ' ON;'
end
Print ''
Print 'INSERT INTO dbo.' + @ipTableName
Print '('
Print @sqlColumns
Print ')'
Print ''
Print 'SELECT '
Print '	' + @lvPKinsert
Print @sqlDefault
Print ''
IF ((SELECT OBJECTPROPERTY( OBJECT_ID(@ipTableName), 'TableHasIdentity')) = 1)
begin
Print 'SET IDENTITY_INSERT dbo.' + @ipTableName + ' OFF;'
end
Print 'END;'
Print 'GO'


--===============================================================================
-- Check for an error 
--===============================================================================
	if @@error <> 0
	begin
		select @lvErrorMsg = 'SP pDDLCreateUTDTable failed'
		goto SQLError
	end

	return (0)

	SQLError:
	begin
		raiserror(@lvErrorMsg, 16, -1)
		return (-1)	
	end
end;
go
