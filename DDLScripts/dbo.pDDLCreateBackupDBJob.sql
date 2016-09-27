
set quoted_identifier on
set ansi_nulls on

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[pDDLCreateBackupDBJob]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[pDDLCreateBackupDBJob]
GO

create procedure dbo.pDDLCreateBackupDBJob
			@ipDBName sysname,
			@ipBackupPath sysname,
			@ipJobStartDate datetime=null,			
			@ipJobStartTime int=null,				--expected format hhmmss 24 hour clock (eg to set job for 6:15pm: 181500)
			@ipType int=1							--determines if backup style for Job Step 2:
															-- 1 = Backup to single device with Init.
															-- 2 = Backup to unique device(eg. Backup_20070101, Backup_20070102 etc) 

as

/**********************************************************************************  
-- Stored Procedure  dbo.pDDLCreateBackupDBJob 
-- Author    RSF   
-- Date     07/18/2007
-- Description   Outputs SQL syntax for creating standard backup of DB
-- Change Hisory    
-- Requires fnValidateUserTimeEntry to validate parameter @ipJobStartTime
--
**********************************************************************************/  

set nocount on  
set transaction isolation level read uncommitted  
  
declare @lvErrorMsg varchar(2000), @lvJobStartDate varchar(8),@lvJobStartTime varchar(6), @lvDBBackupSetName sysname
declare @lvYear varchar(4), @lvMonth varchar(2), @lvDay varchar(2), @lvHour varchar(2), @lvMinute varchar(2), @lvSecond varchar(2)

--SP rule check
If @ipType = 0 or @ipType > 2
	begin
	  set @lvErrorMsg = 'Incorrect value for @ipType;  accepted values are 1 = Backup to device with Init, 2 = Backup to incremental new device (eg. DBBackup_20070101.BAK).  Choose a correct value for input parameter.'
	  goto SQLError 
	end

--Determine Style of recovery
if @ipType=2
	begin
	  set @lvDBBackupSetName='''d' + @ipDBName + '_''''' +  ' +  convert(varchar(10), getdate(), 112) + ' + '''''.bak''' 
	end
else set @lvDBBackupSetName='''d' + @ipDBName + '.bak'''

--calculate optional input date variable
	set @lvYear=datepart(yyyy,isnull(@ipJobStartDate,getdate()))

	if len(datepart(mm,isnull(@ipJobStartDate,getdate())))<2
	  begin
	    set @lvMonth= '0' + cast(datepart(mm,isnull(@ipJobStartDate,getdate())) as varchar(1))
	  end
	  else set @lvMonth=datepart(mm,isnull(@ipJobStartDate,getdate()))

	if len(datepart(dd,isnull(@ipJobStartDate,getdate())))<2
	  begin
	    set @lvDay= '0' + cast(datepart(dd,isnull(@ipJobStartDate,getdate())) as varchar(1))
	  end
	  else set @lvDay=datepart(dd,isnull(@ipJobStartDate,getdate()))

	set @lvJobStartDate=@lvYear+@lvMonth+@lvDay

--calculate optional input time variable
if @ipJobStartTime is null  
 Begin  
 set @lvHour=datepart(hh,getdate())  
  
 if len(datepart(mi,getdate()))<2  
   begin  
     set @lvMinute= '0' + cast(datepart(mi,getdate()) as varchar(1))  
   end  
   else set @lvMinute=datepart(mi,getdate())  
  
 if len(datepart(ss,getdate()))<2  
   begin  
     set @lvSecond= '0' + cast(datepart(ss,getdate()) as varchar(1))  
   end  
   else set @lvSecond=datepart(ss,getdate())  
  
 set @lvJobStartTime=@lvHour+@lvMinute+@lvSecond    
 End  
else
	If (select dbo.fnValidateUserTimeEntry(@ipJobStartTime))=0
		begin
		  set @lvErrorMsg = 'Incorrect value for @ipJobStartTime;  the value entered is outside any accepted time range.  Choose a correct value for input parameter.'
		  goto SQLError 
		end
	else set @lvJobStartTime=@ipJobStartTime  


--Begin Parsing DDL Output Statement
Print 'use [msdb]'
Print 'go'
Print ''
Print 'declare @ReturnCode int'
Print 'set @ReturnCode=0'
Print ''
Print '--	Create Standard Backup job for Production DB ' + @ipDBName
Print 'begin transaction'
Print '	if not exists (select [name] from msdb.dbo.syscategories where [name]=N' + '''[Uncategorized (Local)]''' +' AND category_class=1)
	begin
	  exec @ReturnCode=msdb.dbo.sp_add_category @class=N'+ '''JOB''' + ', @type=N' + '''LOCAL''' + ', @name=N' + '''[Uncategorized (Local)]''' + '
	  if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback
	end

	declare @jobID binary(16)'
Print ''
print '--Step 1.  Create New Job'
Print '	exec @ReturnCode=msdb.dbo.sp_add_job @job_name=N' + '''*d' + @ipDBName + ' Backup''' + ', 
								@enabled=1, 
								@notify_level_eventlog=0, 
								@notify_level_email=0, 
								@notify_level_netsend=0, 
								@notify_level_page=0, 
								@delete_level=0, 
								@description=N' + '''Nightly backup of db''' + ', 
								@category_name=N' + '''[Uncategorized (Local)]''' +', 
								@owner_login_name=N' + '''sa''' + ', @job_id=@jobID output
	if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '--Step 2.  Create Job Steps'
Print '	--2.1	  Run DBCCs'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobstep @job_id=@jobID, @step_name=N' + '''DBCC check''' + ', 
								@step_id=1, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=2, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N' + '''TSQL''' + ', 
								@command=N' + '''DBCC checkDB (' + @ipDBName + ') with all_errormsgs, no_infomsgs
go'''+ ', 
								@database_name=N' + '''master''' +', 
								@flags=0
	IF (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '	--2.2	Backup DB'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobstep @job_id=@jobID, @step_name=N' + '''Backup DB''' + ', 
								@step_id=2, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=3, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N' + '''TSQL''' +', 
								@command=N' + '''use [master] 
go

declare @storagePath sysname,@devicename sysname

set @storagePath=''''' + @ipBackupPath + ''''' 

set @devicename=@storagePath + ''' + @lvDBBackupSetName + '''

select @devicename

BACKUP DATABASE ' + @ipDBName + '
 TO DISK=@devicename with init;

restore verifyonly from disk=@devicename;''' + ',
								@database_name=N' + '''master''' + ', 
								@flags=0
	IF (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '	--2.3	Shrink Database'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobstep @job_id=@jobID, @step_name=N' + '''Shrink Database''' + ', 
								@step_id=3, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=4, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N' + '''TSQL''' + ', 
								@command=N' + '''DBCC SHRINKDATABASE (' + @ipDBName + ',2, truncateonly)''' + ', 
								@database_name=' + @ipDBName + ', 
								@flags=0
	IF (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '	--2.4	Initalize Transaction Log device'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobstep @job_id=@jobID, @step_name=N' + '''Backup Log file''' + ', 
								@step_id=4, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=5, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N' + '''TSQL''' + ', 
								@command=N' + '''BACKUP LOG ' + @ipDBName + '
TO disk=''''' + @ipBackupPath + 'h' + @ipDBName + 'TransactionLog.bak''''
  with init
GO''' + ', 
								@database_name=N' + '''master''' + ', 
								@flags=0
	IF (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '	--2.5	Verify Log Backup Device'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobstep @job_id=@jobID, @step_name=N' + '''Verify Log File Backup''' +', 
								@step_id=5, 
								@cmdexec_success_code=0, 
								@on_success_action=1, 
								@on_success_step_id=0, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N' + '''TSQL''' +', 
								@command=N' + '''restore verifyonly from disk=' + '''''' + @ipBackupPath + 'h' + @ipDBName + 'TransactionLog.bak' + '''''''' + ', 
								@database_name=N' + '''master''' +', 
								@flags=0
	IF (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '--3.  Establish Job Step Starting Point'
Print '	exec @ReturnCode=msdb.dbo.sp_update_job @job_id=@jobID, @start_step_id=1'
Print '	if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '--4.  Create Job Schedule'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobschedule @job_id=@jobID, @name=N' + '''Nightly Backup''' + ', 
								@enabled=1, 
								@freq_type=4, 
								@freq_interval=1, 
								@freq_subday_type=1, 
								@freq_subday_interval=0, 
								@freq_relative_interval=0, 
								@freq_recurrence_factor=0, 
								@active_start_date=' + @lvJobStartDate + ', 
								@active_end_date=99991231, 
								@active_start_time=' + @lvJobStartTime + ', 
								@active_end_time=235959
	   if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print '--5.  Add job to SQL Agent'
Print '	exec @ReturnCode=msdb.dbo.sp_add_jobserver @job_id=@jobID, @server_name=N' + '''(local)''' + '
	if (@@error <> 0 OR @ReturnCode <> 0) goto QuitWithRollback'
Print ''
Print 'commit transaction'
Print ''
Print 'goto EndSave

QuitWithRollback:
    if (@@trancount > 0) rollback transaction

EndSave:'


	if @@error <> 0
		BEGIN
			select @lvErrorMsg = 'SP pDDLCreateBackupDBJob failed'
			goto SQLError
		END

return (0)

/*<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
SQLError:
    if @@trancount > 0
        begin 
            rollback transaction
        end
    raiserror (@lvErrorMsg, 7, -1)
    return (-1)
go

--grant execute on [dbo].[pDDLCreateBackupDBJob] to DBO
--go