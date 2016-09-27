use master;
go

--IP Address used/Connection Info
Select  @@servername,
        connectionproperty('net_transport') as 'NetTransport',
        connectionproperty('protocol_Type') as 'ProtocolType',
        connectionproperty('auth_scheme') as 'AuthScheme',
        connectionproperty('local_net_address') as 'LocalNetAddress',
        connectionproperty('local_tcp_port') as 'LocalTCPPort',
        connectionproperty('client_net_address') as 'ClientNetAddress';
        
--PortNumber 
select  convert(nvarchar(128),serverproperty('ServerName')),
        connectionproperty('local_net_address') as 'IPAddress',
        connectionproperty('local_tcp_port') as 'Port',
        @@version as 'SQLVersion'
from sys.dm_exec_connections
where session_id = @@spid

execute sp_readerrorlog 0,1,N'Server is listening on';
go

--Service account SQL is using
select  ds.servicename,
        ds.startup_type_desc,
        ds.status_desc,
        ds.last_startup_time,
        ds.service_account,
        ds.is_clustered,
        ds.cluster_nodename,
        ds.filename,
        ds.startup_type,
        ds.status,
        ds.process_id
        
from sys.dm_server_services as ds


--Service account, the old way, SQL is using
declare @ServiceAccount nvarchar(128);

execute master.dbo.sp_regread
  'HKEY_LOCAL_MACHINE',
  'System\CurrentControlSet\services\SQLSERVERAGENT',
  'ObjectName',
  @ServiceAccount output;
  
select @ServiceAccount;

execute master.dbo.sp_regread
  'HKEY_LOCAL_MACHINE',
  'System\CurrentControlSet\services\SQLAGENT$InstanceName',
  'ObjectName',
  @ServiceAccount output;

select @ServiceAccount;







  
  
  
  
  
  