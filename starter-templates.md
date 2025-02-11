Below is a list of common SQL/T-SQL patterns and “starter templates” that many teams find useful to document in an internal wiki or snippet library. Each template addresses a recurring scenario or design pattern in SQL. Although the examples here are geared toward **SQL Server (T-SQL)**, many of these ideas carry over to other SQL dialects with minor syntax changes.

---

## 1. TRY...CATCH Error Handling
Using `TRY...CATCH` blocks helps isolate and handle errors within T-SQL batches or stored procedures.

```sql
BEGIN TRY
    BEGIN TRANSACTION;

    -- Execute your statements
    INSERT INTO dbo.TargetTable (Col1, Col2)
    VALUES ('A', 'B');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Capture error details
    SELECT 
        ERROR_NUMBER()     AS ErrorNumber,
        ERROR_SEVERITY()   AS ErrorSeverity,
        ERROR_STATE()      AS ErrorState,
        ERROR_LINE()       AS ErrorLine,
        ERROR_PROCEDURE()  AS ErrorProcedure,
        ERROR_MESSAGE()    AS ErrorMessage;
END CATCH;
```

**When to document this?**  
- Whenever you have critical inserts/updates/deletes that must roll back consistently on error.  
- When you need to log or bubble up error details.

---

## 2. MERGE for “Upsert” Operations
The `MERGE` statement lets you handle inserts, updates, and deletes in one step. It’s often called an “upsert” because it handles both **up**date and in**sert** logic.

```sql
MERGE dbo.TargetTable AS T
USING (SELECT KeyCol, ValCol FROM dbo.SourceTable) AS S
    ON T.KeyCol = S.KeyCol
WHEN MATCHED THEN
    UPDATE SET T.ValCol = S.ValCol
WHEN NOT MATCHED BY TARGET THEN
    INSERT (KeyCol, ValCol)
    VALUES (S.KeyCol, S.ValCol)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;  -- optional
```

**When to document this?**  
- When you frequently integrate or synchronize data between two tables.  
- For building robust ETL processes.

---

## 3. Dynamic SQL with `sp_executesql`
Sometimes you need to build SQL statements on the fly—e.g., when table names, column names, or `WHERE` clauses vary at runtime.

```sql
DECLARE @sql NVARCHAR(MAX) = N'
    SELECT Col1, Col2 
    FROM ' + QUOTENAME(@TableName) + ' 
    WHERE Col3 = @FilterValue
';

EXEC sp_executesql 
    @sql,
    N'@FilterValue INT', 
    @FilterValue = @Parameter;
```

**When to document this?**  
- When constructing queries dynamically to handle flexible table structures or conditional filtering.  
- Emphasize best practices like parameterizing to avoid SQL injection.

---

## 4. Transaction Control Template
This snippet shows an explicit `BEGIN TRAN`, `COMMIT`, or `ROLLBACK` transaction structure:

```sql
BEGIN TRANSACTION;

BEGIN TRY
    -- Perform one or more DML operations
    UPDATE dbo.Table1
    SET ColumnA = 'X'
    WHERE SomeCondition = 1;

    -- If everything is successful, commit
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- If an error occurs, roll back
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Capture or re-throw the error
    THROW;
END CATCH;
```

**When to document this?**  
- When you need atomic operations across multiple statements.  
- Helpful in stored procedures or scripts that update multiple tables.

---

## 5. Recursive CTE (Common Table Expression)
Great for hierarchical data (e.g., org charts, file directories) or for iterative calculations in a single query.

```sql
WITH CTE_Hierarchy AS
(
    SELECT 
        EmployeeID, 
        ManagerID, 
        0 AS Level
    FROM dbo.Employees
    WHERE ManagerID IS NULL

    UNION ALL

    SELECT 
        e.EmployeeID, 
        e.ManagerID, 
        c.Level + 1
    FROM dbo.Employees e
    INNER JOIN CTE_Hierarchy c ON e.ManagerID = c.EmployeeID
)
SELECT *
FROM CTE_Hierarchy
ORDER BY Level;
```

**When to document this?**  
- Organizing data with parent-child relationships.  
- Handling tree or graph-like structures in T-SQL.

---

## 6. PIVOT or UNPIVOT
Transforms row data into columns (PIVOT) or columns into rows (UNPIVOT).

```sql
-- PIVOT example
SELECT
    PivotedCol,
    [Value1] AS Val1,
    [Value2] AS Val2
FROM
(
    SELECT SomeKey, SomeValue, PivotedCol
    FROM dbo.YourTable
) AS SourceData
PIVOT
(
    MAX(SomeValue)
    FOR PivotedCol IN ([Value1], [Value2])
) AS PivotTable;
```

**When to document this?**  
- When you need to rearrange data for reporting or export.  
- When your business logic requires dynamic column creation (sometimes with dynamic SQL).

---

## 7. Window Functions (ROW_NUMBER, RANK, etc.)
Window functions let you perform calculations across sets of rows related to the current row (e.g., computing running totals, ranking, or moving averages).

```sql
SELECT
    ProductID,
    OrderDate,
    ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY OrderDate) AS OrderSeq,
    RANK() OVER (ORDER BY OrderDate) AS GlobalDateRank
FROM dbo.Orders;
```

**When to document this?**  
- For generating row numbers, ranking, or partitioned aggregates without complicated self-joins.

---

## 8. Stored Procedure Template
A standard template for creating stored procedures with parameters, error handling, and comments.

```sql
CREATE OR ALTER PROCEDURE dbo.usp_DoSomething
(
    @Param1 INT,
    @Param2 VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Body of the procedure
        SELECT * 
        FROM dbo.SomeTable
        WHERE Col1 = @Param1
          AND Col2 = @Param2;
    END TRY
    BEGIN CATCH
        -- Handle errors
        SELECT
            ERROR_NUMBER()     AS ErrorNumber,
            ERROR_SEVERITY()   AS ErrorSeverity,
            ERROR_STATE()      AS ErrorState,
            ERROR_LINE()       AS ErrorLine,
            ERROR_PROCEDURE()  AS ErrorProcedure,
            ERROR_MESSAGE()    AS ErrorMessage;

        -- Could log or re-throw the error here
        THROW;
    END CATCH;
END;
GO
```

**When to document this?**  
- Whenever your team creates or updates stored procedures.  
- Ensures consistency in error handling, parameter naming, and documentation.

---

## 9. IF EXISTS / DROP Template (Safe-Drop for Objects)
A snippet for safely dropping and recreating objects (tables, views, procedures, etc.). In newer SQL Server versions:

```sql
-- For a table:
IF OBJECT_ID(N'dbo.TempTable', N'U') IS NOT NULL
    DROP TABLE dbo.TempTable;

-- For a proc (SQL 2016+ syntax):
DROP PROCEDURE IF EXISTS dbo.MyProcedure;
```

**When to document this?**  
- When your deployment pipeline or scripts need to rebuild objects consistently.  
- Ensures that existing objects don’t block new ones with the same name.

---

## 10. Table Variable vs. Temp Table Pattern
Highlighting the differences between using a table variable (`@TableVar`) and a temporary table (`#TempTable`).

```sql
-- Table Variable
DECLARE @TableVar TABLE (ID INT PRIMARY KEY, SomeValue VARCHAR(50));
INSERT INTO @TableVar VALUES (1, 'Alpha'), (2, 'Beta');

-- Temp Table
CREATE TABLE #TempTable (ID INT PRIMARY KEY, SomeValue VARCHAR(50));
INSERT INTO #TempTable VALUES (1, 'Alpha'), (2, 'Beta');
```

**When to document this?**  
- When explaining differences in transaction scope, statistics, indexing capabilities, performance, etc.  
- Provide guidelines on when to use each approach.

---

## 11. Cursor Template (Which You Already Have!)
A pattern for row-by-row processing using a cursor:

```sql
DECLARE @idColumn INT;

DECLARE idCursor CURSOR FAST_FORWARD READ_ONLY
FOR
    SELECT TableID FROM dbo.YourTable ORDER BY TableID;

OPEN idCursor;

FETCH NEXT FROM idCursor INTO @idColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Process @idColumn here

    FETCH NEXT FROM idCursor INTO @idColumn;
END;

CLOSE idCursor;
DEALLOCATE idCursor;
```

**When to document this?**  
- For times when row-by-row processing is unavoidable (though always emphasize set-based solutions first).

---

## Honorable Mentions
- **Backup and Restore Templates** (simple vs. full vs. differential, log backups, etc.)  
- **Index Creation Templates** (covering how to create, rebuild, or reorganize indexes, online vs. offline, etc.)  
- **Bulk Insert / BCP Templates** (common in data warehousing scenarios)  
- **Security & Permissions Templates** (GRANT, REVOKE, CREATE ROLE, etc.)  
- **Partitioning Templates** (how to create partitioned tables and switch partitions for large data movement)

---

Each of the above snippets can form the backbone of a “SQL Developer’s Cheat Sheet,” ensuring everyone on the team has a quick reference for everyday tasks.
