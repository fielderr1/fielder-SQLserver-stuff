USE AdventureWorks2016;
GO
SELECT ROW_NUMBER() OVER(ORDER BY CustomerID, TotalDue DESC) AS RowNum, 
       CustomerID, 
       SalesOrderID, 
       OrderDate, 
       SalesOrderNumber, 
       SubTotal, 
       TotalDue
FROM Sales.SalesOrderHeader


-- Running Total for SQL Server 2012 and Later Version
SELECT ID, Value,
SUM(Value) OVER(ORDER BY ID ROWS UNBOUNDED PRECEDING) AS RunningTotal
FROM TestTable
GO
