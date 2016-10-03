use dbName;
go

select  type_desc, count(*)
from sys.objects 
where type_desc = 'SQL_STORED_PROCEDURE' and
  IS_MS_SHIPPED' =0
group by type_desc
