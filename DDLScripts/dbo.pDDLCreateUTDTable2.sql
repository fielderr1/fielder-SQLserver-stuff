/***************************************************
EXEC dbo.pDDLCreateUTDTable CP_Marketing_un, 'Tami Droste'

Changes I would still like to make:
Output Primary Key
Supress underscores
control commas & semicolon/return on the FK variable by setting @defaults first.  If @defaults = '' then end after the last FK.

--Get a bunch of current records so I don't have to type all the values.
select 'EXEC dbo.utd_OnlineGamingDetail @iPlayerID = ' + CONVERT(varchar,PlayerID) + ', @iExternalGameID = ' + CONVERT(varchar,ExternalGameID) + ', @iExternalGameDescription = ' + char(39) + ExternalGameDescription + char(39) +  ', @iTimePlayed = ' + CONVERT(varchar,TimePlayed) + ', @iCashIn = ' + CONVERT(varchar,CashIn) + ', @iProfitLoss = ' + CONVERT(varchar,ProfitLoss)
FROM onlinegamingdetail
where playerid in (1,2) 

***************************************************/

IF OBJECT_ID('pDDLCreateUTDTable') IS NOT NULL
  DROP PROCEDURE dbo.pDDLCreateUTDTable
GO

CREATE PROCEDURE dbo.pDDLCreateUTDTable
  @ipTableName sysname,
  @iAuthor varchar(64) = NULL
AS
BEGIN

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  

--Create local variables and assign defaults
DECLARE 
  @lvErrorMsg varchar(256),
  @lvUTDName sysname,
  @lvCNT int,
  @lvCreationDate varchar(10),
  @sqlColumns varchar(4000), 
  @sqlSelects varchar(4000),
  @sqlDefault varchar(4000),
  @sqlPKey varchar(4000),
  @sqlFKeys varchar(4000),
  @UTDCalls varchar(4000),
  @lvMaxOrdinal int, 
  @InputParams varchar(4000),
  @Rows int,
  @vIdentityInsertON varchar(256),
  @vIdentityInsertOFF varchar(256);

SELECT	
  @lvErrorMsg = '',
	@lvUTDName = @ipTableName,
	@lvCNT = 0,
	@lvCreationDate = CONVERT(VARCHAR(10),GETDATE(),120),
  @sqlColumns = '',
  @sqlSelects = '',
  @sqlDefault = '',
  @sqlPKey = '',
  @sqlFKeys = '',
  @InputParams = '',
  @UTDCalls = '',
  @vIdentityInsertON = '',
  @vIdentityInsertOFF = '';

--Test input parameter
IF NOT EXISTS(SELECT TOP 1 Name FROM sysobjects WHERE Name = @ipTableName AND xtype = 'U')
BEGIN
	SET @lvErrorMsg='ERROR pDDLCreateUTDTable - Input Table: ' +  @ipTableName + ' does not exist in catalogue. Unable to create utd proc.'
	goto SQLerror;
END

--Create properly formated name for UTD proc
SELECT @lvCNT = patindex('%[_]%',@lvUTDName);
WHILE @lvCNT > 0
BEGIN
	SELECT @lvUTDName = stuff(@lvUTDName,@lvCNT,len(@lvUTDName),substring(@lvUTDName,@lvCNT+1,len(@lvUTDName)))
	SELECT @lvCNT = patindex('%[_]%',@lvUTDName)
END;
SET @lvUTDName = 'utd_' + @lvUTDName;

--Ensure that UTD doesn't already exist
IF EXISTS(SELECT TOP 1 Name FROM sysobjects WHERE Name = @lvUTDName AND xtype = 'P')
BEGIN
	SET @lvErrorMsg='ERROR pDDLCreateUTDTable - PROC: ' +  @lvUTDName + ' already exists in catalogue. Investigate.'
	GOTO SQLerror;
END;

--Get the highest Ordinal Position in the table
SELECT TOP 1
  @lvMaxOrdinal = Ordinal_Position
FROM information_schema.columns
WHERE Table_Name = @ipTableName
  AND Column_Name NOT IN ('RowVersion')
ORDER BY Ordinal_Position DESC;

--Get Input Parameter List
SELECT 
  @InputParams = @InputParams + SPACE(2) + '@i' 
  + CASE WHEN patindex('%[_]%',Column_name) > 0 THEN stuff(Column_name,patindex('%[_]%',Column_name),1,'') ELSE Column_name END 
  + ' ' + Data_type +
  CASE Data_type
    WHEN 'numeric' THEN '(' + cast(numeric_precision as varchar(3)) + ',' + cast(numeric_scale as varchar(3)) +')'
    WHEN 'varchar' THEN '(' + isnull(cast(Character_Maximum_Length as varchar(6)),'') + ')'
    WHEN 'char' THEN '(' + isnull(cast(Character_Maximum_Length as varchar(6)),'') + ')'
    ELSE isnull(cast(Character_Maximum_Length as varchar(6)),'')
  END + ' = NULL' + 
  CASE WHEN ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) THEN ',' + CHAR(13) + CHAR(10) ELSE '' END
FROM information_schema.columns
WHERE Table_Name = @ipTableName
  AND Column_Name NOT IN ('RowVersion')
ORDER BY Ordinal_Position

--Get Insert column list
SELECT 
  @sqlColumns = @sqlColumns + SPACE(4) + Column_Name + case when ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) then ',' + CHAR(13) + CHAR(10) else '' end
FROM information_schema.columns
WHERE Table_Name = @ipTableName
  AND Column_Name NOT IN ('RowVersion')
ORDER BY Ordinal_Position

--Get Insert select list
SELECT 
  @sqlSelects = @sqlSelects + SPACE(4) + '@i' + CASE WHEN patindex('%[_]%',Column_name) > 0 THEN stuff(Column_name,patindex('%[_]%',Column_name),1,'') ELSE Column_name END + case when ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) then ',' + CHAR(13) + CHAR(10) else ';' end
FROM information_schema.columns
WHERE Table_Name = @ipTableName
  AND Column_Name NOT IN ('RowVersion')
ORDER BY Ordinal_Position

--Get the highest Ordinal Position of the primary key(s) in the table
SELECT TOP 1
  @lvMaxOrdinal = Ordinal_Position
FROM information_schema.table_constraints tc
  INNER JOIN information_schema.key_column_usage ku on tc.constraint_type = 'primary key' and tc.constraint_name = ku.constraint_name
WHERE ku.Table_Name = @ipTableName
  AND ku.Column_Name NOT IN ('RowVersion')
ORDER BY Ordinal_Position DESC;

--Set Defaults for PK
SELECT
  @sqlPKey = @sqlPKey + SPACE(4) + '@i' + CASE WHEN patindex('%[_]%',Column_name) > 0 THEN stuff(Column_name,patindex('%[_]%',Column_name),1,'') ELSE Column_name END 
    + ' = ISNULL(@i' + CASE WHEN patindex('%[_]%',Column_name) > 0 THEN stuff(Column_name,patindex('%[_]%',Column_name),1,'') ELSE Column_name END 
    + ',(ISNULL((SELECT TOP 1 ' + Column_Name + ' FROM dbo.' + @ipTablename + ' ORDER BY ' + Column_Name + ' DESC),0) + 1))' 
    + case when ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) then ',' + CHAR(13) + CHAR(10) else '' end
FROM information_schema.table_constraints tc
  INNER JOIN information_schema.key_column_usage ku on tc.constraint_type = 'primary key' and tc.constraint_name = ku.constraint_name
WHERE ku.table_name = @ipTableName
  AND Column_Name NOT IN ('RowVersion')
ORDER BY Ordinal_Position

--Set Defaults for FKs
  --List of parent tables for the FKs and their row counts in a new DB.  If populated by an init, then just select the max FK ID. Otherwise,
  --we have to create the record in the parent table via a UTD.
SELECT
  TOP 100 IDENTITY(int) FKID,
  kcu2.Table_Name TableName,
  kcu1.Column_Name ColumnName,
  0 CurrentRowCount
INTO ##ForeignKeys
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
  INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu1 ON kcu1.constraint_name = rc.constraint_name
  INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu2 ON kcu2.constraint_name = rc.unique_constraint_name
WHERE kcu1.Table_Name = @ipTablename --'SpeedMediaTriggerAward'

UPDATE ##ForeignKeys 
SET CurrentRowCount = (SELECT i.Rows FROM sysindexes i WHERE i.indid < 2 AND i.id = OBJECT_ID(TableName))

--Reset max Ordinal position variable so that it just counts the FK columns that need UTDs.
SELECT TOP 1
  @lvMaxOrdinal = FKID
FROM ##ForeignKeys
WHERE CurrentRowCount = 0
ORDER BY FKID DESC;

SELECT
  @UTDCalls = @UTDCalls + SPACE(2) + 'IF @i' + CASE WHEN patindex('%[_]%',ColumnName) > 0 THEN stuff(ColumnName,patindex('%[_]%',ColumnName),1,'') ELSE ColumnName END + ' IS NULL' + char(13) + char(10) + ' ' + SPACE(4) + 'EXEC @i' + CASE WHEN patindex('%[_]%',ColumnName) > 0 THEN stuff(ColumnName,patindex('%[_]%',ColumnName),1,'') ELSE ColumnName END + ' = utd_' + TableName + case when FKID <> cast(@lvMaxOrdinal as varchar(12)) then ';' + CHAR(13) + CHAR(10) else '' end 
FROM ##ForeignKeys
WHERE CurrentRowCount = 0

--Reset max Ordinal position variable so that it just counts the FK columns that need FK values from init tables.
SELECT TOP 1
  @lvMaxOrdinal = FKID
FROM ##ForeignKeys
WHERE CurrentRowCount > 0
ORDER BY FKID DESC;

SELECT
  @sqlFKeys = @sqlFKeys + SPACE(4) + '@i' + CASE WHEN patindex('%[_]%',ColumnName) > 0 THEN stuff(ColumnName,patindex('%[_]%',ColumnName),1,'') ELSE ColumnName END + ' = ISNULL(@i' + CASE WHEN patindex('%[_]%',ColumnName) > 0 THEN stuff(ColumnName,patindex('%[_]%',ColumnName),1,'') ELSE ColumnName END + ',(ISNULL((SELECT TOP 1 ' + ColumnName + ' FROM dbo.' + TableName + ' ORDER BY ' + ColumnName + ' DESC),1)))' + case when FKID <> cast(@lvMaxOrdinal as varchar(12)) then ',' + CHAR(13) + CHAR(10) else '' end
FROM ##ForeignKeys
WHERE CurrentRowCount > 0

DROP TABLE ##ForeignKeys

--Reset max Ordinal position variable so that it just counts the columns that need a default value
SELECT TOP 1
  @lvMaxOrdinal = Ordinal_Position
FROM information_schema.columns
WHERE Table_Name = @ipTableName
  AND Column_Name NOT IN ('RowVersion')
  AND Is_Nullable = 'no'
ORDER BY Ordinal_Position DESC;

--Set Defaults; Does not include FKs or the PK
SELECT 
  @sqlDefault = @sqlDefault + 
  CASE 
    WHEN Is_Nullable = 'no' THEN SPACE(4) + '@i' + CASE WHEN patindex('%[_]%',Column_name) > 0 THEN stuff(Column_name,patindex('%[_]%',Column_name),1,'') ELSE Column_name END + ' = ISNULL(' + '@i' + CASE WHEN patindex('%[_]%',Column_name) > 0 THEN stuff(Column_name,patindex('%[_]%',Column_name),1,'') ELSE Column_name END + ','
      + CASE Data_Type
						WHEN 'bit' THEN '0'
						WHEN 'int' THEN '0'
						WHEN 'tinyint' THEN '0'
						WHEN 'smallint' THEN '0'
						WHEN 'bigint' THEN '0000000'
						WHEN 'numeric' THEN '0.00'
						WHEN 'money' THEN '0.00'
						WHEN 'char' THEN '''N'''
						WHEN 'real' THEN '0'  
						WHEN 'float' THEN '0.00'
						WHEN 'varchar' THEN  '''N'''
						WHEN 'datetime' THEN 'GETDATE()'
						WHEN 'smalldatetime' THEN 'GETDATE()'
					END
      + ')' + CASE WHEN ordinal_position <> cast(@lvMaxOrdinal as varchar(12)) THEN ',' + CHAR(13) + CHAR(10) else ';' end
    ELSE '' 
 		END
  FROM information_schema.columns 
  WHERE table_name = @ipTableName
    AND Column_Name NOT IN ('RowVersion')
    AND Column_Name NOT IN 
    (
      SELECT cl.Column_Name
      FROM information_schema.table_constraints tc
        INNER JOIN information_schema.key_column_usage ku on tc.constraint_type = 'primary key' and tc.constraint_name = ku.constraint_name
        LEFT JOIN information_schema.columns cl on ku.Column_Name = cl.Column_Name and ku.table_name = cl.table_name
      WHERE ku.table_name = @ipTableName
    )
    AND Column_Name NOT IN 
    (
      SELECT cl.Column_Name
      FROM information_schema.table_constraints tc
        INNER JOIN information_schema.key_column_usage ku on tc.constraint_type = 'foreign key' and tc.constraint_name = ku.constraint_name
        LEFT JOIN information_schema.columns cl on ku.Column_Name = cl.Column_Name and ku.table_name = cl.table_name
      WHERE ku.table_name = @ipTableName
    )
  ORDER BY Ordinal_Position;

--Check for Identity column
IF OBJECTPROPERTY(OBJECT_ID(@ipTableName), 'TableHasIdentity') != 0
BEGIN
  SELECT @vIdentityInsertON = '  SET IDENTITY_INSERT dbo.' + @ipTableName + ' ON;'
  SELECT @vIdentityInsertOFF = '  SET IDENTITY_INSERT dbo.' + @ipTableName + ' OFF;'
END

--Create the script
Print 'IF OBJECT_ID(' + char(39) + 'dbo.' + @lvUTDName + char(39) + ') IS NOT NULL'
Print '	DROP PROCEDURE dbo.'  + @lvUTDName
Print 'GO'
Print '' 
Print '/*************************************************************************************
DATE        VERSION         AUTHOR                              '
Print @lvCreationDate + '	11.6.2          ' + @iAuthor + '			
Initial Creation


--Test Me'
PRINT 'BEGIN TRAN'
Print 'EXEC dbo.' + @lvUTDName
Print 'SELECT * FROM ' + @ipTableName
Print 'ROLLBACK TRAN
*************************************************************************************/'
Print ''
Print 'CREATE PROCEDURE dbo.' + @lvUTDName
Print '('
Print @InputParams
Print ')'
Print 'AS'
Print 'BEGIN

  SET NOCOUNT ON;'
Print ''
Print @UTDCalls
PRINT ''
Print '  SELECT'
Print @sqlPKey + ','
Print @sqlFKeys
Print @sqlDefault
Print ''
Print @vIdentityInsertON
Print ''
Print '  INSERT INTO dbo.' + @ipTableName
Print '  ('
Print @sqlColumns
Print '  )'
Print '  SELECT '
Print @sqlSelects
Print ''
Print @vIdentityInsertOFF
Print 'END'
Print 'GO'

--===============================================================================
-- Check for an error 
--===============================================================================
	if @@error <> 0
	begin
		select @lvErrorMsg = 'SP pDDLCreateUTDTable failed'
		goto SQLError
	end

	return (0)

	SQLError:
	begin
		raiserror(@lvErrorMsg, 16, -1)
		return (-1)	
	end
end;




