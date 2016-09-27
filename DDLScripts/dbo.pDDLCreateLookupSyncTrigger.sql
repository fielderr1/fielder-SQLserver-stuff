

set quoted_identifier on
set ansi_nulls on

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[pDDLCreateLookupSyncTrigger]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[pDDLCreateLookupSyncTrigger]
GO

create procedure dbo.pDDLCreateLookupSyncTrigger
			@ipTableName sysname							

as

/**********************************************************************************  
-- Stored Procedure  dbo.pDDLCreateLookupSyncTrigger 
-- Author    RSF   
-- Date     10/23/2006  
-- Description   populates tLookup for global access to lookup values to datalayer
-- Change Hisory    
--  
--
**********************************************************************************/  

set nocount on  
set transaction isolation level read uncommitted  
  
declare @lvErrorMsg varchar(200)
declare @lvPKcolumn varchar(128)

set @lvPKcolumn=(select cu.column_name	from information_schema.key_column_usage cu
					join information_schema.table_constraints cs on cu.constraint_name=cs.constraint_name and cs.constraint_type='PRIMARY KEY'
					where cu.table_name=@ipTableName)

	  if not exists(select 1 from information_schema.table_constraints where constraint_type='PRIMARY KEY' and table_name=@ipTableName)
		begin
		  set @lvErrorMsg='ERROR pDDLCreateLookupSyncTrigger - Table: ' +  @ipTableName + ' does not have a Primary Key defined you must create table with appropriate column constraints'
		  goto SQLerror
		end

	if @lvPKcolumn<>'ID'
		begin 
		  set @lvErrorMsg='ERROR pDDLCreateLookupSyncTrigger - Table: ' +  @ipTableName + ' Primary Key Column Name does not conform to DB standards please rename to [ID]'
		  goto SQLerror
		end

Print '--LookupSync dbo.tiu' + substring(@ipTableName,2,254) + '_LookupSync'
Print 'if object_id(N' + '''' + 'dbo.tiu' + substring(@ipTableName,2,254) + '_LookupSync' + '''' + ') is not null' 
Print '	begin'
Print '		drop trigger dbo.tiu' + substring(@ipTableName,2,254) + '_LookupSync'
Print '	end'
Print 'GO'
Print ''
Print 'create trigger dbo.tiu' + substring(@ipTableName,2,254) + '_LookupSync on dbo.' + @ipTableName
Print '	for insert, update' 
Print '	  as '
Print '	update lk'	
Print '	set lk.LookupDescription=ins.LookupDescription,'
Print '		lk.EnabledFlag=ins.EnabledFlag,'
Print '		lk.DisplayOrder=ins.DisplayOrder,'
Print '		lk.XMLtext=ins.XMLtext'
Print '	from dbo.tLookup lk'
Print '		join inserted ins'
Print '		  on lk.id=ins.id and lk.LookupName = ' + '''' + substring(@ipTableName,2,254) + ''''
Print ''
Print ' insert dbo.tLookup (LookupName,ID,LookupDescription,EnabledFlag,DisplayOrder,XMLText)'	 
Print '	Select	' + '''' + substring(@ipTableName,2,254) + '''' + ','
Print '			ins.ID,'
Print '			ins.LookupDescription,'
Print '			ins.EnabledFlag,'
Print '			ins.DisplayOrder,'
Print '			ins.XMLText'
Print '	from inserted ins'
Print '		left join dbo.tLookup lk'
Print '		  on lk.id=ins.id and lk.ID is null and lk.LookupName = ' + '''' + substring(@ipTableName,2,254) + ''''
Print 'GO'
Print ''
Print '--delete trigger for lookupsync'
Print 'if object_id(N' + '''' + 'dbo.td' + substring(@ipTableName,2,254) + '_LookupSync' + '''' + ') is not null' 
Print '	begin'
Print '		drop trigger dbo.td' + substring(@ipTableName,2,254) + '_LookupSync'
Print '	end'
Print 'GO'
Print ''
Print 'create trigger dbo.td' + substring(@ipTableName,2,254) + '_LookupSync on dbo.' + @ipTableName
Print '	for delete' 
Print '	  as '
Print '	delete lk'	
Print '	from deleted del'
Print '		join dbo.tLookup lk'
Print '		  on lk.id=del.id and lk.LookupName = ' + '''' + substring(@ipTableName,2,254) + ''''
Print 'GO'

		--===============================================================================
		-- Check for an error 
		--===============================================================================
	if @@error <> 0
		BEGIN
			select @lvErrorMsg = 'SP pDDLCreateLookupSyncTrigger failed'
			goto SQLError
		END

return (0)

SQLError:
		begin
			raiserror(@lvErrorMsg, 16, -1)
			return (-1)	
		end
go

--grant execute on [dbo].[pDDLCreateLookupSyncTrigger] to DBO
--go