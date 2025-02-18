Below is a **“missing indexes”** script you can add to your toolkit. Identifying potentially missing indexes often provides **quick wins** when it comes to **SQL Server performance**—especially for heavy OLTP or mixed workloads. After all, a well-chosen index can drastically reduce I/O and CPU usage for frequent queries.
> **Note**: Don’t blindly create every index this DMV suggests—review each recommendation for redundancy and potential overhead (e.g., slower writes, extra storage). But this is a **great** starting point to see where you might gain the most performance benefit quickly.
---
1. **Creates** (or drops and re-creates) the helper function `dbo.ufn_SafeIndexName`.  
2. **Runs** the “Find Missing Indexes” query that uses the function.  

You can run this entire script at once in SSMS or Azure Data Studio, and it will produce your sanitized “CREATE INDEX” statements, all without needing separate files.

---

## Script: Identify Missing Indexes and Generate Recommendations

```sql
/*
    ================================================================================
    Script  : FindMissingIndexes_SafeNames_OneScript
    Author  : Nathanael Ries
    Date    : 2/13/2025
    Purpose :
        1. Creates (or replaces) a helper function [dbo].[ufn_SafeIndexName] for 
           generating safe index names in compliance with T-SQL rules.
        2. Uses the Missing Index DMVs to find potential indexes and produce a 
           CREATE INDEX script that won't break due to invalid chars or length.
    ================================================================================
*/

/*=============================================================================
  1) Drop existing function if it already exists (optional safety check)
=============================================================================*/
IF OBJECT_ID('dbo.ufn_SafeIndexName', 'FN') IS NOT NULL
    DROP FUNCTION dbo.ufn_SafeIndexName;
GO

/*=============================================================================
  2) Create the helper function [dbo].[ufn_SafeIndexName]
=============================================================================*/
CREATE FUNCTION dbo.ufn_SafeIndexName
(
    @FullTableName     NVARCHAR(4000),
    @EqualityCols      NVARCHAR(4000),
    @InequalityCols    NVARCHAR(4000)
)
RETURNS NVARCHAR(128)
AS
/*
    Purpose:
        Generates a valid, short index name by:
        - Removing invalid/special characters: [ ] . , space
        - Truncating the name if it exceeds 128 chars
        - Using a prefix of "IX_" + short table name + short column reference
*/
BEGIN
    DECLARE @Candidate NVARCHAR(300) = N''; 
    DECLARE @SafeTable NVARCHAR(100) = @FullTableName;
    DECLARE @SafeCols  NVARCHAR(100) = ISNULL(@EqualityCols, '') + ISNULL(@InequalityCols, '');

    --------------------------------------------------------------------------------
    -- 1) Remove brackets, dots, commas, spaces, etc. from table & column strings
    --------------------------------------------------------------------------------
    SET @SafeTable = REPLACE(REPLACE(@SafeTable, '[', ''), ']', '');
    SET @SafeTable = REPLACE(REPLACE(@SafeTable, '.', '_'), ',', '_');
    SET @SafeTable = REPLACE(@SafeTable, ' ', '_'); -- optional

    SET @SafeCols = REPLACE(REPLACE(@SafeCols, '[', ''), ']', '');
    SET @SafeCols = REPLACE(REPLACE(@SafeCols, '.', '_'), ',', '_');
    SET @SafeCols = REPLACE(@SafeCols, ' ', '_');

    --------------------------------------------------------------------------------
    -- 2) Truncate both table name and column reference to avoid 128-char limit
    --    We'll take e.g. 40 chars from table, 20 from columns, adjust as needed.
    --------------------------------------------------------------------------------
    SET @SafeTable = LEFT(@SafeTable, 40); 
    SET @SafeCols  = LEFT(@SafeCols, 20);

    --------------------------------------------------------------------------------
    -- 3) Construct a candidate index name: "IX_" + [table] + "_" + [cols]
    --------------------------------------------------------------------------------
    SET @Candidate = 'IX_' + @SafeTable + '_' + @SafeCols;

    --------------------------------------------------------------------------------
    -- 4) If the resulting name is still > 128, truncate
    --------------------------------------------------------------------------------
    IF LEN(@Candidate) > 128
        SET @Candidate = LEFT(@Candidate, 128);

    --------------------------------------------------------------------------------
    -- 5) Return bracketed name
    --------------------------------------------------------------------------------
    RETURN N'[' + @Candidate + N']';
END;
GO

/*=============================================================================
  3) The Missing Indexes Query: now references [dbo].[ufn_SafeIndexName]
=============================================================================*/

WITH MissingIndexInfo AS
(
    SELECT 
          migs.group_handle,
          mid.database_id,
          mid.[statement]                  AS TableOrViewName,
          mid.equality_columns             AS equality_columns,
          mid.inequality_columns           AS inequality_columns,
          mid.included_columns             AS included_columns,
          migs.unique_compiles             AS TimesQueried,
          migs.user_seeks                  AS Seeks,
          migs.user_scans                  AS Scans,
          migs.last_user_seek              AS LastSeek,
          migs.avg_total_user_cost         AS AvgQueryCost,
          migs.avg_user_impact             AS AvgImpact,
          (migs.avg_total_user_cost * migs.avg_user_impact) AS WeightedImprovement
    FROM sys.dm_db_missing_index_group_stats AS migs
    INNER JOIN sys.dm_db_missing_index_groups AS mig
        ON migs.group_handle = mig.index_group_handle
    INNER JOIN sys.dm_db_missing_index_details AS mid
        ON mig.index_handle = mid.index_handle
)
SELECT TOP 50  -- limit to top 50 suggestions
      DB_NAME(mi.database_id)                        AS DatabaseName
    , mi.TableOrViewName                             AS TableName
    , mi.equality_columns                            AS EqualityCols
    , mi.inequality_columns                          AS InequalityCols
    , mi.included_columns                            AS IncludedCols
    , mi.TimesQueried                                AS UniqueCompiles
    , mi.Seeks
    , mi.Scans
    , mi.WeightedImprovement                         AS EstimatedBenefit
    , N'CREATE INDEX '
        + [dbo].[ufn_SafeIndexName](mi.TableOrViewName, mi.equality_columns, mi.inequality_columns)
        + N' ON ' + mi.TableOrViewName
        + N' ('
            + COALESCE(mi.equality_columns, '')
            + CASE 
                WHEN mi.equality_columns IS NOT NULL 
                     AND mi.inequality_columns IS NOT NULL 
                THEN N', '
                ELSE N''
              END
            + COALESCE(mi.inequality_columns, '')
        + N')'
        + CASE WHEN mi.included_columns IS NOT NULL 
               THEN ' INCLUDE (' + mi.included_columns + ')'
               ELSE ''
          END
        + N';'
      AS ProposedCreateIndex
FROM MissingIndexInfo AS mi
ORDER BY mi.WeightedImprovement DESC;
```

### Explanation of the One-Script Approach

1. **Helper Function Creation**  
   - The first part checks if the function `dbo.ufn_SafeIndexName` already exists and drops it. Then it **creates** the function.  
   - `GO` batches separate the function’s creation from the next parts.

2. **Query Execution**  
   - Right after creating the function, the script proceeds to the `WITH MissingIndexInfo AS ... SELECT ...` portion.  
   - Because the function now exists, SQL Server can resolve it during the query.

3. **All in One File**  
   - You don’t need to run separate scripts. Just run this entire file in **SQL Server Management Studio** (SSMS) or **Azure Data Studio**, and you’ll get your results.

4. **Any Additional Logic**  
   - If you want to create a **temp table** or produce more advanced T-SQL logic (like generating an “AllInOne” script for actual index creation), you can extend this single file.  

---

## Tips for Using This Single Script

- **Save & Reuse**  
  Store it in **source control** (Git, TFS, etc.), so you can quickly re-run it in different environments.
  
- **Adjust the Helper Function**  
  - If you want more unique or descriptive index names, you can incorporate **hashing** (e.g., `CHECKSUM` or `HASHBYTES`) or a **timestamp**.  
  - If you want to keep columns in the index name, just limit the length.  

- **Test for Collisions**  
  - If two suggestions produce the **same** truncated index name, you may see a “duplicate index name” error.  
  - You can add logic to the function to ensure uniqueness (e.g., append part of a GUID).

- **Validate Before You Create**  
  - The script only **suggests** indexes. Some might be duplicates or partial overlaps of existing ones.

---

**In summary**, the above single script handles both **function creation** and the **missing index query** in one go. Simply copy/paste into SSMS or your favorite SQL client and run it. You’ll get sanitized, valid index create statements without having to juggle multiple scripts.
