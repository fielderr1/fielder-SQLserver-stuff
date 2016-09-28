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

--Service account SQL is using 2k8
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



--stackoverflow.com/questions/7324407/get-service-account-details-of-the-agent-service
--Service account, the old way, SQL is using
declare @ServiceAccount nvarchar(128);

--default instance
execute master.dbo.xp_regread
  'HKEY_LOCAL_MACHINE',
  'System\CurrentControlSet\services\SQLSERVERAGENT',
  'ObjectName',
  @ServiceAccount output;
  
select @ServiceAccount;

--named instance
execute master.dbo.xp_regread
  'HKEY_LOCAL_MACHINE',
  'System\CurrentControlSet\services\SQLAGENT$InstanceName',
  'ObjectName',
  @ServiceAccount output;

select @ServiceAccount;

----or
declare @DBEngineLogin nvarchar(128),@SQLAgentLogin nvarchar(128),@SQLAgentStartType varbinary(64);

execute master.dbo.xp_instance_regread
  @RootKey = N'HKEY_LOCAL_MACHINE',
  @Key = N'System\CurrentControlSet\services\MSSQLServer',
  @Value_Name = N'ObjectName',
  @Value = @DBEngineLogin output;
  
execute master.dbo.xp_instance_regread
  @RootKey = N'HKEY_LOCAL_MACHINE',
  @Key = N'System\CurrentControlSet\services\SQLServerAgent',
  @Value_Name = N'ObjectName',
  @Value = @SQLAgentLogin output;
  
execute master.dbo.xp_instance_regread
  @RootKey = N'HKEY_LOCAL_MACHINE',
  @Key = N'System\CurrentControlSet\services\SQLServerAgent',
  @Value_Name = N'Start',    --002000 AutoMatic, 003000 Manual
  @Value = @SQLAgentStartType output;
  
select @DBEngineLogin as 'DBEngineLogin',
       @SQLAgentLogin as 'SQLAgentLogin',
       @SQLAgentStartType as 'SQLAgentStartType';
go

--another option
Declare @Agent nvarchar(512)

select @Agent = coalesce(N'SQLAgent$' + convert(sysname,serverproperty('InstanceName')),N'SQLServerAgent';

execute master.dbo.xp_servicecontrol 'QueryState', @agent;
