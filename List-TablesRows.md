## Script: List Tables with Row Counts & Comments

```sql
/*
    ================================================================================
    Script  : ListTablesWithRowCountsAndComments
    Author  : Nathanael Ries
    Date    : March 31 2022
    Purpose : 
        Retrieves a list of all user tables in the current database, displaying:
            - Schema & Table Name
            - Creation & Last Modification Date
            - Row Count (based on sys.partitions)
            - Table Comments (Extended Properties)
    ================================================================================
*/

SELECT 
      sch.name                  AS SchemaName
    , tbl.name                  AS TableName
    , tbl.create_date           AS CreatedDate
    , tbl.modify_date           AS LastModifiedDate
    , COALESCE(rc.RowCount, 0)  AS RowCount
    , ep.value                  AS Comments
FROM sys.tables AS tbl
INNER JOIN sys.schemas AS sch
    ON tbl.schema_id = sch.schema_id

-- Retrieve row counts from sys.partitions, using only heap (0) or clustered (1) indexes
LEFT JOIN 
(
    SELECT 
          p.object_id
        , SUM(p.rows) AS RowCount
    FROM sys.partitions AS p
    WHERE p.index_id IN (0,1)    -- 0 = Heap; 1 = Clustered index
    GROUP BY p.object_id
) AS rc
    ON tbl.object_id = rc.object_id

-- Retrieve any extended property named 'MS_Description' for the table
LEFT JOIN sys.extended_properties AS ep
    ON tbl.object_id = ep.major_id
    AND ep.minor_id  = 0
    AND ep.name      = 'MS_Description'
    AND ep.class_desc = 'OBJECT_OR_COLUMN'

ORDER BY 
      sch.name
    , tbl.name;
```

---

## Documentation

### Overview
This query provides a **one-stop view** of all user tables in the current database, including:

1. **Schema & Table Name**  
2. **Creation Date & Last Modification Date**  
3. **Approximate Row Count**  
4. **Comments (Description) from Extended Properties**  

It leverages the **system catalog views** (`sys.tables`, `sys.schemas`, `sys.partitions`, `sys.extended_properties`) to gather metadata in a single result set.

### Column-by-Column Explanation

- **SchemaName**  
  The name of the schema containing the table (e.g., `dbo`, `Sales`).

- **TableName**  
  The name of the table within that schema.

- **CreatedDate**  
  The date and time the table was originally created.

- **LastModifiedDate**  
  The date and time the table’s definition was last modified (e.g., if columns were added or removed).

- **RowCount**  
  The total number of rows in the table, **summed** from `sys.partitions` for the **heap** (index_id = 0) or **clustered index** (index_id = 1). This count is often quite accurate, but keep in mind it can be **slightly outdated** in high-transaction environments. If you need an absolutely exact count, use `SELECT COUNT(*) FROM table;` (which can be slow on large tables).

- **Comments**  
  Any **extended property** named `MS_Description` associated with the table object. This is the standard property name SQL Server Management Studio (SSMS) uses for table descriptions.

### Usage Scenarios

- **Documentation & Discovery**  
  Quickly see what tables exist in the database, who owns them (schema), when they were created/modified, and any documented comments (metadata).

- **Auditing & Cleanup**  
  Identify large or obsolete tables by sorting or filtering on `RowCount` or `LastModifiedDate`.

- **Metadata Exports**  
  Use the result set to generate data dictionaries or to power documentation tools.

### Notes & Best Practices

1. **Row Count Accuracy**  
   - The counts in `sys.partitions` are generally reliable, but in highly transactional databases, they may not be in perfect sync with real-time counts.  
   - For absolutely precise row counts, do a direct `COUNT(*)` on the table.

2. **Extended Properties**  
   - By default, this script retrieves only the property `MS_Description`, which is the commonly used “Comment” field in SSMS. If you store comments under different property names, adjust the `ep.name` filter.

3. **Performance Considerations**  
   - This query runs quickly on system catalog views, but in massive environments with hundreds or thousands of tables, consider limiting the result set to a specific schema or set of tables if needed.

4. **Custom Sorting**  
   - The example uses `ORDER BY SchemaName, TableName`. If you’d prefer to see the largest tables first, you can switch to `ORDER BY RowCount DESC`.

---

**Summary**: This script is a handy reference for **database administrators** and **developers** who want a quick, summarized view of all tables in a database, the number of rows in each, and any comments or descriptions attached to them.
