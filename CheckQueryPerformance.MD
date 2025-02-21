## Monitoring Long Running and High Impact Queries in SQL Server

When diagnosing performance issues, it’s important to know which queries are consuming the most resources or running longer than expected. The following script leverages SQL Server’s dynamic management views (DMVs) to provide a snapshot of:

- **Active long running queries** from `sys.dm_exec_requests`.  
- **High impact queries** captured in `sys.dm_exec_query_stats`.  
- **Wait statistics** from `sys.dm_os_wait_stats` to further pinpoint system-level delays.

> **Note**: Adjust thresholds (e.g., the 30-second limit for long running queries) and filters as needed for your specific environment. Always test in a non-production setting first.

---

### SQL Script: Check Query Performance

```sql
/*
    ================================================================================
    Script  : CheckQueryPerformance
    Author  : [Your Name]
    Date    : [Date]
    Purpose :
        1. Identify long running queries currently executing on the server.
        2. Retrieve the top 10 high impact queries based on cumulative CPU time.
        3. Display top wait statistics to help diagnose potential bottlenecks.
    ================================================================================
*/

-- Part 1: Identify Long Running Queries (running for more than 30 seconds)
SELECT 
    r.session_id,
    r.status,
    r.command,
    r.start_time,
    DATEDIFF(SECOND, r.start_time, GETDATE()) AS DurationSeconds,
    r.cpu_time,
    r.total_elapsed_time,
    SUBSTRING(st.text, (r.statement_start_offset/2) + 1, 
              ((CASE r.statement_end_offset 
                   WHEN -1 THEN DATALENGTH(st.text)
                   ELSE r.statement_end_offset 
                END - r.statement_start_offset)/2) + 1) AS QuerySnippet
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id <> @@SPID
  AND DATEDIFF(SECOND, r.start_time, GETDATE()) > 30
ORDER BY DurationSeconds DESC;

-- Part 2: Retrieve Top 10 High Impact Queries (by total CPU usage)
SELECT TOP 10
    qs.sql_handle,
    qs.plan_handle,
    qs.execution_count,
    qs.total_worker_time AS TotalCPUTime,
    qs.total_elapsed_time AS TotalElapsedTime,
    qs.total_logical_reads AS TotalLogicalReads,
    qs.total_logical_writes AS TotalLogicalWrites,
    qs.creation_time,
    qs.last_execution_time,
    SUBSTRING(st.text, 1, 500) AS QueryText
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY qs.total_worker_time DESC;

-- Part 3 (Optional): Check Top 10 Wait Statistics for Additional Insights
SELECT TOP 10
    wait_type,
    wait_time_ms,
    max_wait_time_ms,
    signal_wait_time_ms,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
    'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'LOGMGR_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'XE_DISPATCHER_JOIN'
)
ORDER BY wait_time_ms DESC;
```

---

### Explanation of the Script

1. **Identifying Long Running Queries**  
   The first query inspects `sys.dm_exec_requests` to list sessions that have been active for more than 30 seconds. It uses `CROSS APPLY` with `sys.dm_exec_sql_text` to extract a snippet of the executing query. This helps quickly spot any sessions that might be causing performance issues.

2. **Retrieving High Impact Queries**  
   The second query uses `sys.dm_exec_query_stats` to identify the top 10 queries that have consumed the most CPU time overall. By examining historical performance data (including execution count, CPU time, and I/O metrics), you can pinpoint queries that may require optimization.

3. **Checking Wait Statistics (Optional)**  
   The third query retrieves the top wait types from `sys.dm_os_wait_stats`, excluding common benign waits. This gives additional context regarding where the server may be experiencing delays, such as from I/O or CPU contention.

---

### When to Use This Script

- **Performance Troubleshooting**: If your SQL Server instance is experiencing slowdowns or high CPU usage, these queries help identify problematic queries and underlying wait issues.
- **Regular Monitoring**: Incorporate these queries into routine health checks to monitor query performance and resource consumption.
- **Post-Changes Review**: Use after configuration changes or query modifications to assess the impact on performance.

---

### Best Practices & Caveats

- **Test Before Production**: As with any monitoring tool, validate the script in a non-production environment to ensure it meets your needs.
- **Customize Thresholds**: The 30-second runtime threshold is a general guideline. Adjust this value based on the typical performance characteristics of your workload.
- **Interpret Wait Stats Carefully**: High wait times can indicate various issues. Use these stats in conjunction with other performance metrics to determine the root cause.
- **Holistic Monitoring**: While this script focuses on query-level performance, always consider other factors (such as hardware resources and overall system load) when troubleshooting.

---

**In summary**, this SQL script provides a starting point for monitoring long running and high impact queries in SQL Server. By regularly reviewing these metrics, DBAs can proactively identify and address performance bottlenecks, ensuring smoother operations and better resource utilization.

