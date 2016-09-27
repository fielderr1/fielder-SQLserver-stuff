
set quoted_identifier on
set ansi_nulls on

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[pDDLCompressAllUserTables]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
	drop procedure [dbo].[pDDLCompressAllUserTables]
GO

create procedure dbo.pDDLCompressAllUserTables

--find all compressed tables
SELECT DISTINCT
SERVERPROPERTY('servername') [instance]
,DB_NAME() [database]
,QUOTENAME(OBJECT_SCHEMA_NAME(sp.object_id)) +'.'+QUOTENAME(Object_name(sp.object_id))[table]
,ix.name [index_name]
,sp.data_compression
,sp.data_compression_desc
FROM sys.partitions SP
LEFT OUTER JOIN sys.indexes IX
ON sp.object_id = ix.object_id
and sp.index_id = ix.index_id
WHERE sp.data_compression <> 0
ORDER BY 2;


--generate ddl to compress tables
SET NOCOUNT ON
SELECT 'ALTER TABLE ' + '[' + s.[name] + ']'+'.' + '[' + o.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);'
FROM sys.objects AS o WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON o.[object_id] = i.[object_id]
INNER JOIN sys.schemas AS s WITH (NOLOCK)
ON o.[schema_id] = s.[schema_id]
INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
ON i.[object_id] = ps.[object_id]
AND ps.[index_id] = i.[index_id]
WHERE o.[type] = 'U'
ORDER BY ps.[reserved_page_count]



Print 'goto EndSave

QuitWithRollback:
    if (@@trancount > 0) rollback transaction

EndSave:'


	if @@error <> 0
		BEGIN
			select @lvErrorMsg = 'SP pDDLCompressAllUserTables failed'
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

--grant execute on [dbo].[pDDLCompressAllUserTables] to DBO
--go