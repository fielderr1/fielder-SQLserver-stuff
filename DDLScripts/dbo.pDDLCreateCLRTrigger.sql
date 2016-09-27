
set quoted_identifier on
set ansi_nulls on

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[pDDLCreateCLRTrigger]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[pDDLCreateCLRTrigger]
GO

create procedure dbo.pDDLCreateCLRTrigger
			@ipTableName sysname,
			@ipTriggerName sysname,
			@ipAssemblyName sysname			

as

/**********************************************************************************  
-- Stored Procedure  dbo.pDDLCreateCLRTrigger 
-- Author    RSF   
-- Date     12/01/2006  
-- Description   Outputs SQL syntax for assembly triggers
-- Change Hisory    
--  
--
**********************************************************************************/  

set nocount on  
set transaction isolation level read uncommitted  
  
declare @lvErrorMsg varchar(200)

Print '--	Create CLR trigger SQL for table' + @ipTableName
Print 'if object_id(' + quotename(@ipTriggerName, '''') + ') is not null drop trigger ' + @ipTriggerName
Print 'GO'
Print 'create trigger ' + @ipTriggerName
Print '	on ' + @ipTableName + ' for insert, update, delete'
Print '	as external name ' + @ipAssemblyName + '.[' + @ipAssemblyName + '.Triggers].' + @ipTriggerName
Print 'GO'
Print ''


		--===============================================================================
		-- Check for an error 
		--===============================================================================
	if @@error <> 0
		BEGIN
			select @lvErrorMsg = 'SP pDDLCreateCLRTrigger failed'
			goto SQLError
		END

return (0)

SQLError:
		begin
			raiserror(@lvErrorMsg, 16, -1)
			return (-1)	
		end
go

--grant execute on [dbo].[pDDLCreateCLRTrigger] to DBO
--go