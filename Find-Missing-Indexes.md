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

### How It Works
1. **DMVs Used**  
   - **`sys.dm_db_missing_index_details`**: Shows which columns in each table are needed for equality, inequality, and included columns.  
   - **`sys.dm_db_missing_index_group_stats`** and **`sys.dm_db_missing_index_groups`**: Store statistics such as the number of seeks, scans, and average query cost impact for those missing indexes.
2. **Weighted Improvement**  
   - We multiply `avg_total_user_cost` by `avg_user_impact` to get a rough measure of which missing indexes might bring the most overall benefit.
3. **Automatic Script Generation**  
   - The final column, `ProposedCreateIndex`, builds a **basic CREATE INDEX statement** that you can copy, inspect, and tweak.
### Key Columns in the Output
- **`DatabaseName`**: The database for which the missing index is suggested.  
- **`TableName`**: The table (or view) name from which columns are missing.  
- **`EqualityCols` & `InequalityCols`**: Which columns should be placed in the key portion of the index (first equality, then inequality).  
- **`IncludedCols`**: Columns recommended as included columns. Typically, these do not form part of the key.  
- **`UniqueCompiles`**, **`Seeks`**, **`Scans`**: Basic usage stats for how often queries referencing these columns have executed without an ideal index.  
- **`EstimatedBenefit`**: A heuristic measure of how much time might be saved by implementing this index, based on how expensive the related queries are and how often they run.  
- **`ProposedCreateIndex`**: An auto-generated “CREATE INDEX” statement.
### Usage Scenarios
- **Performance Triage**: When you suspect the server is slow due to missing or sub-optimal indexes, this is a quick way to see the biggest offenders.  
- **Proactive Maintenance**: Periodically review these DMVs to catch new or evolving query patterns in your workloads.  
- **Migration or New Deployment**: Right after a large data migration or application release, check if new queries are missing indexes.
### Best Practices & Recommendations
1. **Validate Before Creating**  
   - Check for **duplicate or overlapping** indexes you might already have.  
   - Consider whether a composite index might handle **both** the new suggestions and existing needs.
2. **Monitor Disk & Write Overhead**  
   - Each new index takes up **disk space** and can **slow down inserts/updates**. Always weigh the read-vs-write tradeoff.
3. **Don’t Rely Solely on DMVs**  
   - SQL Server’s suggestions can miss advanced indexing strategies (e.g., filtered indexes, columnstore indexes, etc.).  
   - For specialized workloads (like heavily partitioned tables or large data warehouses), you may need to analyze usage patterns more deeply.
4. **Rotate or Archive**  
   - The missing index DMVs reset every time SQL Server restarts or the database is detached. Keep that in mind if you’re doing longer-term trending.
5. **Always Test**  
   - Implement indexes in a non-production or staging environment first if possible. Evaluate query execution plans and performance improvements in real or near-real workloads.
---
**In summary**, this **Missing Indexes** script is a powerful tool for **quick performance tuning wins**. It helps sysadmins and DBAs discover what indexes SQL Server’s engine sees as beneficial, but always remember to **validate** and **prioritize** any recommended indexes before rolling them out to production.

---

