use master;
go

--dbs involved in replication
select is_published,is_subscribed,is_merge_published, is_distributor,is_cdc_enabled,is_broker_enabled, * from sys.databases

--DB objects that are replicated
SELECT tbl.ID,
		tbl.Name,
		tbl.ReplInfo

FROM sysobjects tbl
	JOIN sysusers usr
	  ON usr.uid = tbl.uid
WHERE usr.name = 'dbo' and
	  tbl.xtype = 'U' and
	  tbl.ReplInfo = 1
