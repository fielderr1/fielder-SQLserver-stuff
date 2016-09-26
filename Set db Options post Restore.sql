Use master;
go

----set recovery model to simple for all dbs
----changed dbOwner to SA 
----fix orphan users from restore

declare @SQLdbrecovery nvarchar(2048),@SQLdbowner nvarchar(2048),@SQLdborphan nvarchar(256),@name sysname;

Select	@SQLdbrecovery = 'alter database ',
	@SQLdbowner = 'use ',
	@SQLdborphan = 'use ';

declare ServerDBSetting cursor 
for

	select name from sys.databases where database_id > 4 and is_read_only = 0  and name not in 'Distribution';

	open ServerDBSetting
	fetch next from ServerDBSetting into @name

	Select	@SQLdbrecovery = @SQLdbrecovery  + '[' + @name + ']' + ' set recovery simple;',
		@SQLdbowner = @SQLdbowner + '[' + @name + ']' + ' execute sp_changedbowner [sa];',
		@SQLdborphan = @SQLdborphan + '[' + @name + ']';

	while @@fetch_status = 0
	begin

		--Print @SQLdbrecovery
		--Print @SQLdbowner
		--Print @SQLdborphan
		execute sp_sqlexec @SQLdbrecovery;
		execute sp_sqlexec @SQLdbowner;

		--set db context to correct any orphan users
		execute sp_sqlexec @SQLdborphan;

			--collect db users to fix
			declare @login nvarchar(64)

			declare UserLogin cursor for

			select '[' + name + ']' from sys.sysusers where uid > 4 and uid < 1000 and name not like '##%';

			open UserLogin
			fetch next from UserLogin into @login
			while @@fetch_status = 0
			begin
				--Print @login
				exectue sp_change_users_login 'auto_fix', @login
				fetch next from UserLogin into @login
			end
			close UserLogin
			deallocate UserLogin

		Select	@SQLdbrecovery = 'alter database ',@SQLdbowner = 'use ',@SQLdborphan = 'use ';

		fetch next from ServerDBsetting into @name
		Select	@SQLdbrecovery = @SQLdbrecovery  + '[' + @name + ']' + ' set recovery simple;',
			@SQLdbowner = @SQLdbowner + '[' + @name + ']' + ' execute sp_changedbowner [sa];',
			@SQLdborphan = @SQLdborphan + '[' + @name + ']';
	end
close ServerDBsetting
deallocate ServerDBsetting




