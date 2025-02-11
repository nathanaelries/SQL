Below is a **simple, recommended** T-SQL script to perform a **full backup** of a single database. It’s minimal by design—perfect as a “starter” script or quick reference. You can expand upon it (e.g., add **compression**, **checksum**, or **encryption**) for more advanced scenarios.

---

# Wiki Article: Simple SQL Server Database Backup

## Overview
A **full backup** captures the entire content of a database at a specific point in time. Performing regular full backups is the foundation of any disaster recovery plan. Below is a basic one-statement script that’s easy to remember and execute.

## Script: Full Database Backup

```sql
BACKUP DATABASE [YourDatabaseName]
TO DISK = N'C:\Backups\YourDatabaseName_Full.bak'
WITH INIT, 
     STATS = 10;
```

### Explanation
- **`YourDatabaseName`**  
  Replace this placeholder with the actual name of the database you want to back up (enclose in brackets if the name has special characters/spaces).
- **`TO DISK = 'C:\Backups\YourDatabaseName_Full.bak'`**  
  Specifies the backup **destination file** path. Adjust the directory to a valid path on your server.  
- **`WITH INIT`**  
  Overwrites the existing backup file if it already exists. If you prefer appending backups, omit this option.  
- **`STATS = 10`**  
  Displays progress every 10% during the backup. You can change the percentage or remove this entirely.

## Best Practices & Recommendations

1. **Use a Dedicated Backup Location**  
   - Store backups on a **separate drive** from your data files. This improves recoverability if the primary data drive fails.  
   - If possible, consider storing backups on **network shares** or **cloud storage** for offsite recovery.

2. **Enable Compression** (Where Supported)  
   - Many SQL Server editions support backup compression, which can **shrink backup size** and **speed up** the operation.  
   - To enable compression:
     ```sql
     BACKUP DATABASE [YourDatabaseName]
     TO DISK = N'C:\Backups\YourDatabaseName_Full.bak'
     WITH INIT, 
          COMPRESSION,
          STATS = 10;
     ```

3. **Schedule Regular Backups**  
   - A single, manual backup is fine occasionally, but most production environments need automated, **recurring** backups (full, differential, and transaction log).  
   - Use **SQL Server Agent Jobs**, **Maintenance Plans**, or **third-party tools** to handle scheduling and retention.

4. **Check the Recovery Model**  
   - In **Full** or **Bulk-Logged** recovery models, transaction logs can grow large if log backups aren’t taken regularly.  
   - If your database is **Simple** recovery, log backups aren’t applicable, but you’ll have fewer point-in-time recovery options.

5. **Validate & Test**  
   - After backups complete, test them periodically by **restoring** to a test environment.  
   - Check the **msdb** database tables (`backupset`) to ensure backups are happening on schedule.

6. **Keep Security in Mind**  
   - Backup files can contain **sensitive data**; store them securely.  
   - Consider using **encryption** (`WITH ENCRYPTION`) if data security is a concern.

## When to Use This Script
- **Single Database, Quick Backup**: Perfect for one-off full backups on smaller servers or dev environments.  
- **Basic Disaster Recovery Setup**: If you’re just starting with backups, this script is a building block before adding differentials or log backups.  
- **Testing or Migrating**: Easy to lift-and-shift a database by creating a full backup, then restoring elsewhere.

## Summary
Performing a **full backup** is crucial for safeguarding your SQL Server data. The above one-liner with `BACKUP DATABASE ... TO DISK` is the simplest and most commonly recommended T-SQL approach. For more complex requirements—like compression, log backups, or automated scheduling—build upon this foundation to align with your organization’s **Recovery Point/Time Objectives** (RPO/RTO).
