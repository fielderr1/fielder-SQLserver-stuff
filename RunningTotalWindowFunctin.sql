-- Running Total for SQL Server 2012 and Later Version
SELECT ID, Value,
SUM(Value) OVER(ORDER BY ID ROWS UNBOUNDED PRECEDING) AS RunningTotal
FROM TestTable
GO
