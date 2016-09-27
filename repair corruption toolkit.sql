use master;
go

--all dbcc commands with help including undocumented
dbcc traceon(2588);
dbcee ('?');
dbcc traceoff(2588);

--Error:  The database ID 6, Page(1:938873), slot 51 for LOB data type node does not exist
--http://www.sqlskills.com/blogs/paul/finding-table-name-page-id/

execute sp_helpdb;

dbcc checkdb [mydatabase];

--get data from suspect pages
select * from msdb.dbo.suspect_pages;
go

--Metadata: ObjectId
dbcc traceon(3604);
dbcc page (16,1,15295,0);
dbcc traceoff(3604);

--object name; if null wrong db context change to correct db or metadata for the db is corrupt wait for checkdb to complete
use mydatabase;
select object_name(885578194);
go

use mydatabase;
dbcc checktable (AllUserData);
go

--repair DB allow dataloass as any suspect transactions should be rolledback as they are just that suspect
use mydatabase;
dbcc checkdb(mydatabase,repair_allow_data_loss);
go

--dbcc WritePage
--http://www.sqlskills.com/blogs/paul/corruption-recovery-using-dbcc-writepage/



