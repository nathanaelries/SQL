Below is a **multi-part script** that helps you:

1. **Check the last full, differential, and transaction log backups** for each user database.  
2. **See the current log file size** (in MB) for each database.  
3. **Receive a basic recommendation** on transaction log backup frequency if the log file is large or if the last log backup is old.

> **Disclaimer**  
> - This script provides **general heuristics**. Always tailor recommendations to your **RPO/RTO requirements** (Recovery Point/Time Objectives) and specific workload patterns.  
> - For production environments with critical data, ensure your backup strategy and log management are part of a broader **Disaster Recovery** plan.

---

## Script: Check Backups & Log File Sizes, Provide Recommendations

```sql
/*
    ================================================================================
    Script  : CheckBackupsAndLogSize
    Author  : [Your Name]
    Date    : [Date]
    Purpose : 
        1. List last full, differential, and transaction log backups for each database.
        2. Show the total size of the transaction log file(s) in MB.
        3. Suggest if the log backup frequency might need to be increased.
    ================================================================================
*/

--==============================================================================
-- 1. Gather Last Full, Diff, and Log Backup Times from msdb
--==============================================================================

;WITH LastFull AS
(
    SELECT 
          bs.database_name,
          MAX(bs.backup_finish_date) AS LastFullBackup
    FROM msdb.dbo.backupset AS bs
    WHERE bs.[type] = 'D'         -- D = Full Database Backup
    GROUP BY bs.database_name
),
LastDiff AS
(
    SELECT 
          bs.database_name,
          MAX(bs.backup_finish_date) AS LastDiffBackup
    FROM msdb.dbo.backupset AS bs
    WHERE bs.[type] = 'I'         -- I = Differential Backup
    GROUP BY bs.database_name
),
LastLog AS
(
    SELECT 
          bs.database_name,
          MAX(bs.backup_finish_date) AS LastLogBackup
    FROM msdb.dbo.backupset AS bs
    WHERE bs.[type] = 'L'         -- L = Log Backup
    GROUP BY bs.database_name
),

--==============================================================================
-- 2. Calculate Total Log File Size (in MB) for each database
--    (Excluding system databases if desired)
--==============================================================================

LogFileSizes AS
(
    SELECT 
          d.name AS DatabaseName,
          CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(12,2)) AS LogSizeMB  -- Each 'size' unit = 8 KB
    FROM sys.databases AS d
    INNER JOIN sys.master_files AS mf
        ON d.database_id = mf.database_id
    WHERE mf.type_desc = 'LOG'                -- Only log files
      AND d.database_id NOT IN (1,2,3,4)      -- Exclude master, tempdb, model, msdb if desired
    GROUP BY d.name
)

--==============================================================================
-- 3. Combine Results & Suggestion Logic
--==============================================================================

SELECT 
      d.name AS DatabaseName
    , CONVERT(VARCHAR(19), f.LastFullBackup, 120)  AS LastFullBackup
    , CONVERT(VARCHAR(19), di.LastDiffBackup, 120) AS LastDiffBackup
    , CONVERT(VARCHAR(19), l.LastLogBackup, 120)   AS LastLogBackup
    , ls.LogSizeMB
    , CASE 
        WHEN ls.LogSizeMB IS NULL THEN 'No log file info' 
        WHEN ls.LogSizeMB >= 1024  THEN 'Large log file (>=1GB)'
        ELSE 'Normal size'
      END AS LogSizeStatus
    , CASE 
        WHEN l.LastLogBackup IS NULL 
             THEN 'No log backups detected! Consider configuring log backups.'
        WHEN ls.LogSizeMB >= 1024  
             AND DATEDIFF(HOUR, l.LastLogBackup, GETDATE()) >= 4 
             THEN 'Log is large and last log backup > 4 hours ago. Consider increasing backup frequency.'
        WHEN ls.LogSizeMB >= 512  
             AND DATEDIFF(HOUR, l.LastLogBackup, GETDATE()) >= 8 
             THEN 'Log is moderately large and last log backup > 8 hours ago. Consider more frequent log backups.'
        ELSE 'Backup frequency appears typical.'
      END AS Recommendation
FROM sys.databases AS d
LEFT JOIN LastFull AS f
    ON d.name = f.database_name
LEFT JOIN LastDiff AS di
    ON d.name = di.database_name
LEFT JOIN LastLog AS l
    ON d.name = l.database_name
LEFT JOIN LogFileSizes AS ls
    ON d.name = ls.DatabaseName
WHERE d.database_id NOT IN (1,2,3,4)  -- Exclude master, tempdb, model, msdb if desired
ORDER BY d.name;
```

---

## Explanation of Key Parts

1. **Backup History (msdb.dbo.backupset)**  
   - We collect the **last** time a **full** (`type = 'D'`), **differential** (`type = 'I'`), and **transaction log** (`type = 'L'`) backup finished, grouping by `database_name`.  
   - If you see `NULL` in these columns for user databases, that means no backup of that type was taken (or the history was purged).

2. **Log File Sizes (sys.master_files)**  
   - We sum the size of **all log file(s)** for each database, converting from 8KB pages to MB.  
   - This helps identify large or growing transaction logs.

3. **Heuristic Recommendation**  
   - The final `SELECT` uses a **CASE** expression to provide simple guidance. For example:
     - If the **log file** is **>= 1GB** **and** the last log backup was **over 4 hours** ago, we suggest increasing backup frequency.  
     - If the log is “moderately large” (>= 512 MB) and the last log backup was **> 8 hours** ago, a nudge is also displayed.

4. **Excluding System Databases**  
   - System DBs (like `master`, `model`, `msdb`, `tempdb`) typically follow different backup/recovery strategies. Adjust the `WHERE` clause as needed.

---

## Why This Matters

- **Log Backups Prevent Log Growth**  
  If you use the **Full** or **Bulk-Logged** recovery model, the transaction log won’t truncate unless you perform **log backups**. Neglecting these can lead to **excessive log growth**, consuming disk space.

- **Full & Differential Backups**  
  Are critical to establishing your **recovery point** and also reduce the size of subsequent differential and log backups.

- **Performance & Storage**  
  Large, un-backed-up transaction logs can lead to performance issues (e.g., disk I/O pressure), as well as potential data loss if the disk fills up or you’re forced to switch the database to Simple recovery.

---

## Practical Tips & Best Practices

1. **Check Recovery Models**  
   - Confirm each user database is in the correct **Recovery Model** (Full, Bulk-Logged, or Simple).  
   - If you don’t need point-in-time recovery, consider **Simple** to avoid large logs.

2. **Automate Backups**  
   - Use SQL Server Agent jobs, **Maintenance Plans**, or third-party tools to schedule regular **full**, **diff**, and **log** backups.  
   - Ensure you have **alerting** in place if a job fails.

3. **Monitor Disk Space**  
   - Keep an eye on the drive(s) that store your log files. If near capacity, urgent log backups or additional disk space may be needed.

4. **Use This Report Regularly**  
   - Incorporate it into your DBA **health checks** or weekly reviews.  
   - If you see a pattern of frequently large logs, consider both **increasing log backup frequency** and possibly **index or query tuning** to reduce large transactions.

5. **Historical Trends**  
   - The `msdb.dbo.backupset` table is often pruned depending on your backup retention policy. For historical analysis, consider storing backups metadata in a separate logging table or using third-party monitoring.

---

### In Summary

This script surfaces:

- **When** your databases last received Full, Differential, and Log backups,  
- **How big** each database’s transaction log file is, and  
- **Whether** you might want to **increase log backup frequency** based on heuristic thresholds.

By regularly running or scheduling this report, you can **prevent excessive log growth**, ensure your backups are timely, and maintain a sound **disaster recovery** posture.
