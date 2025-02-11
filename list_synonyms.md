## Script: View Synonym Details

```sql
/*
    ================================================================================
    Script  : ViewSynonymDetails
    Author  : Nathanael Ries
    Date    : March 31 2022
    Purpose : 
        Retrieves detailed information about each synonym in the current database, 
        including the server, database, schema, and object name that the synonym 
        references (where applicable).
    ================================================================================
*/

SELECT 
      s.name                                AS SynonymName
    , s.base_object_name                    AS SynonymDefinition
    , COALESCE(PARSENAME(s.base_object_name, 4), @@SERVERNAME)      AS ServerName
    , COALESCE(PARSENAME(s.base_object_name, 3), DB_NAME())         AS DatabaseName
    , COALESCE(PARSENAME(s.base_object_name, 2), SCHEMA_NAME())     AS SchemaName
    , PARSENAME(s.base_object_name, 1)                              AS ObjectName
    , s.create_date
    , s.modify_date
FROM sys.synonyms AS s
ORDER BY s.name;
```

---

## Documentation

### Purpose
This query helps you quickly view **all synonyms** defined in the current database. It also breaks down each synonym’s base object name (the target) into **server**, **database**, **schema**, and **object** components using the built-in [`PARSENAME()`](https://learn.microsoft.com/en-us/sql/t-sql/functions/parsename-transact-sql) function. If any parts are missing (e.g., a synonym references an object in the same database without server or database qualifiers), the script uses `COALESCE` to **default** them to:
- The **current server** (`@@SERVERNAME`),
- The **current database** (`DB_NAME()`),
- The **current schema** (`SCHEMA_NAME()`).

### Columns Explained
- **SynonymName**: The name of the synonym as it appears in this database.  
- **SynonymDefinition**: The fully (or partially) qualified path to the actual object the synonym references, e.g., `[ServerName].[DatabaseName].[SchemaName].[ObjectName]`.  
- **ServerName**: If provided by the synonym’s definition, this is extracted by `PARSENAME(..., 4)`. Otherwise, we default to `@@SERVERNAME`.  
- **DatabaseName**: Extracted by `PARSENAME(..., 3)`. Defaults to the current database if not specified.  
- **SchemaName**: Extracted by `PARSENAME(..., 2)`. Defaults to the current schema if not specified.  
- **ObjectName**: Extracted by `PARSENAME(..., 1)`, which typically is the underlying table, view, or another synonym.  
- **create_date**: Timestamp indicating when the synonym was originally created.  
- **modify_date**: Timestamp indicating the last time the synonym definition was modified.

### When to Use
- **Auditing**: Quickly see how many synonyms exist in a database and what objects they point to.  
- **Maintenance**: Confirm references when cleaning up, moving, or renaming objects.  
- **Troubleshooting**: Identify broken synonyms, especially if the referenced object or database no longer exists.

### Limitations
1. **Special Characters**: If the base object name includes periods (`.`) or special characters without proper quoting/bracketing, `PARSENAME` may not parse it correctly.  
2. **Remote Synonyms**: If the synonym references an external server or linked server, it must be fully qualified for the parts to appear in the correct order.  
3. **Partial References**: Many synonyms in the same database omit server or database qualifiers, which is why `COALESCE` defaults them to the local server/database/schema.

### Example Usage
1. **Identify Local vs. Remote Objects**: You can quickly see which synonyms reference external servers by checking if the `ServerName` column is different from `@@SERVERNAME`.  
2. **Check Synonym Age**: Look at `create_date` or `modify_date` to find newly added or recently updated synonyms.  
3. **Prepare for Migration**: Before moving a database, use this script to locate synonyms pointing to objects in other databases or servers that may need to be recreated or adjusted post-migration.

---

**In summary,** this template provides a straightforward way to analyze synonyms in a SQL Server database. It neatly splits out the 1–4 part naming convention used by `base_object_name` and helps you verify or document each reference.
