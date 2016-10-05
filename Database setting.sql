Use master;
go

--select log_reuse_wait_desc, is_cdc_enabled, is_broker_enabled, is_published,is_subscribed,is_merge_published, is_distributor, * from sys.databases


if not exists(select 1 from sys.databases where name ='dbName' and is_broker_enabled = 0)
begin
	alter database dbName set enable_broker with rollback immediate;
end 


--check recovery model
select name,recovery_model_desc from sys.databases

--check ompatibility level
select compatibility_level from sys.databases where name = 'dbName'
--alter database dbName set compatibility_level = 120

--clr
select * from sys.configurations where name ='clr enabled'

--Service Broker
select name,is_broker_enabled from sys.databases

alter database mydatabase set enable_broker with rollback immediate;


