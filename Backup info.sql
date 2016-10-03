use dbNameHere;
go

--get backup hisotry for required db
select top 10
  bs.database_name 'dbName',
  mf.physical_device_name,
  cast(cast(bs.backup_size/1000000 as ont) as varchar(14)) + ' ' + 'mb' as 'bkSize',
  cast(datediff(second, bs.backup_start_date,bs.backup_finish_date) as varch(4)) + ' ' + 'seconds' as 'TimeTaken',
  bs.backup_start_date,
  cas(bs.first_lsn as varchchar(64)) as 'FirstLSN',
  cas(bs.last_lsn as varchchar(64)) as 'LastLSN',
  case bs.type
    when 'i' then 'Differential'
    when 'l' then 'TransactionLog'
    when 'd' then 'Full'
  end as 'bkType'
  bs.server_name as 'ServerName'
  bs.recovery_model as 'RecoveryModel'
from msdb.dbo.BackupSet bs
  inner join msdb.dbo.BackupMediaFamily mf on bs.media_set_id = mf.media_set_id
where bs.database_name = db_name() and
  bs.type = 'd'  -full backup only filter
order by backup_start_date desc
    
