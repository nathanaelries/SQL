## Script: Find Columns by Name in a Specific Database

```sql
/*
    ================================================================================
    Script  : FindColumnsByName
    Author  : Nathanael Ries
    Date    : March 31 2022
    Purpose : 
        Searches all columns in a given database for a particular string in their names.
    ================================================================================
*/

SELECT 
      TABLE_SCHEMA  AS SchemaName
    , TABLE_NAME    AS TableName
    , COLUMN_NAME   AS ColumnName
    , DATA_TYPE     AS DataType
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = db_name()
  AND COLUMN_NAME LIKE '%<SearchString>%'
ORDER BY 
      TABLE_SCHEMA
    , TABLE_NAME
    , COLUMN_NAME;
```

### Where to Customize

1. **`<SearchString>`**  
   - Replace with the substring you want to find within column names.  
   - You can use SQL wildcard characters (`%`) for partial matches.

---

## Documentation

### Overview

This script locates columns across **all user tables** (and views) within a specified database whose names contain a particular search string. For example, you might want to find columns that contain “Date,” “ID,” or “Price.”

### Columns Returned

- **SchemaName**  
  The schema that contains the table or view.

- **TableName**  
  The name of the table or view.

- **ColumnName**  
  The name of the column that matches the specified search string.

- **DataType**  
  The SQL data type of the matching column (e.g., `INT`, `VARCHAR`, `DATETIME`).

### Why Use `INFORMATION_SCHEMA.COLUMNS`?
- **Standards-Compliant**: `INFORMATION_SCHEMA` views are ISO/ANSI-compliant, making your code more portable across different SQL dialects.
- **Ease of Filtering**: These views provide straightforward columns like `TABLE_CATALOG`, `TABLE_SCHEMA`, `TABLE_NAME`, `COLUMN_NAME`, etc., for easy filtering.

### Usage Scenarios
1. **Column Discovery**: Quickly locate where a particular field or phrase appears in column names—useful in large databases for data mapping or refactoring.  
2. **Schema Documentation**: Generate partial data dictionaries when you only know part of a column name.  
3. **Refactoring**: Find all columns that might need renaming or adjusting based on your search criteria.

### Customizations

- **Filter by Schema**: If you want to narrow the results to a specific schema (e.g., `dbo`), add `AND TABLE_SCHEMA = 'dbo'` to the `WHERE` clause.  
- **Include More Metadata**: For additional insights, you can select more columns from `INFORMATION_SCHEMA.COLUMNS`, such as `CHARACTER_MAXIMUM_LENGTH`, `IS_NULLABLE`, or `COLUMN_DEFAULT`.  
- **Exclude Views**: By default, `INFORMATION_SCHEMA.COLUMNS` includes columns from both tables and views. If you only want tables, consider joining with `INFORMATION_SCHEMA.TABLES` and adding `WHERE TABLE_TYPE = 'BASE TABLE'`.

### Notes & Best Practices
- This query **only searches column names**, not actual data values.  
- The search is **case-insensitive** by default in SQL Server unless you’ve configured a case-sensitive collation.  
- Large databases: Searching is typically fast because `INFORMATION_SCHEMA.COLUMNS` is a system view, but consider any performance impacts in very large environments.

---

**In summary,** this script is a go-to tool when you know part of a column’s name but aren’t sure which table or schema it belongs to. It’s particularly useful in **data discovery**, **clean-up**, and **documentation** tasks.
