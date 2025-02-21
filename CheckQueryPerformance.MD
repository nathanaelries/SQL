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

---

Below is a general guide on **how to interpret** and **what actions you might take** with the results shown in your screenshot (which likely come from the script checking high-impact queries and top wait stats). The key is to use these results to **pinpoint potential performance bottlenecks** and **decide on targeted optimizations**.

---

## 1. High-Impact Queries (Top Query Stats)

In your first result set, you’ll see columns like:

- **`sql_handle` / `plan_handle`**: Identifiers for the query’s execution plan in SQL Server’s cache.  
- **`execution_count`**: How many times the query has run.  
- **`total_worker_time`**: Cumulative CPU time (in microseconds). Higher values = more CPU consumption overall.  
- **`total_elapsed_time`**: Total wall-clock time spent.  
- **`total_logical_reads` / `total_logical_writes`**: Amount of I/O (in 8 KB pages) the query has generated.  
- **`creation_time`** / **`last_execution_time`**: When the plan was first cached, and the most recent execution.  
- **`QueryText`**: Snippet of the SQL statement.

### What to do with this data

1. **Identify CPU-Intensive or I/O-Heavy Queries**  
   - Look for queries with exceptionally high `total_worker_time` (CPU) or `total_logical_reads` (I/O).  
   - If the same query has run thousands of times (`execution_count`) with high resource usage, it’s a prime candidate for tuning.

2. **Examine Execution Plans**  
   - Retrieve the full execution plan using the query’s `plan_handle` (for instance, `sys.dm_exec_query_plan(qs.plan_handle)`), or run the query with “Include Actual Execution Plan” in SSMS to see where the bottlenecks might be (e.g., expensive index scans, key lookups, missing indexes, or parameter sniffing issues).

3. **Check for Missing or Inefficient Indexes**  
   - Large I/O reads often indicate missing or non-optimal indexes. SQL Server’s “Missing Index” hints (from execution plans or `sys.dm_db_missing_index_details`) can guide you.  
   - Evaluate if an index can help reduce scans, or if you need to adjust an existing index to better cover the query.

4. **Rewrite or Simplify Queries**  
   - If the query is overly complex, break it down or use temporary tables to manage intermediate results.  
   - Sometimes even small changes (e.g., appropriate JOINs, sargable WHERE clauses) can significantly reduce CPU or I/O.

5. **Parameter Sniffing**  
   - If performance is inconsistent, parameter sniffing might be an issue. Consider using “OPTION (RECOMPILE)” selectively, or evaluate different ways to handle parameters (local variables, forced parameterization, etc.).

---

## 2. Top Wait Statistics

In the second result set, you’ll see columns like:

- **`wait_type`**: The name of the wait (e.g., `PAGEIOLATCH_SH`, `CXPACKET`, `SOS_SCHEDULER_YIELD`, etc.).  
- **`wait_time_ms`**: Cumulative time spent waiting (in milliseconds).  
- **`max_wait_time_ms`**: The longest single wait for that wait type.  
- **`signal_wait_time_ms`**: Time waiting for CPU after the resource became available (often used to diagnose CPU pressure).  
- **`waiting_tasks_count`**: How many tasks encountered that wait.

### What to do with this data

1. **Identify the Most Common Wait Types**  
   - If you see `PAGEIOLATCH_*` or `IO_COMPLETION` near the top, that often indicates disk I/O bottlenecks (slow or overloaded storage).  
   - `CXPACKET` (or `CXCONSUMER` in newer versions) may indicate parallelism waits. This could mean you need to adjust `MAXDOP`, or that certain queries are using too many threads.  
   - `LATCH_*` or `LOCK_*` waits can suggest concurrency issues or hot pages in memory.  
   - `SOS_SCHEDULER_YIELD` can point to CPU pressure.

2. **Correlate Waits with High-Impact Queries**  
   - If a high-CPU query is running and you see `SOS_SCHEDULER_YIELD` as a top wait, that query may be causing CPU pressure.  
   - If `PAGEIOLATCH_SH` or `PAGEIOLATCH_EX` is high, check if your top queries are reading large amounts of data from disk.

3. **Consider Hardware or Configuration Tuning**  
   - For I/O waits, investigate storage performance, or consider adding memory (to reduce physical reads) if that’s a constraint.  
   - For CPU-related waits, examine CPU usage, parallelism settings (`MAXDOP`, `cost threshold for parallelism`), and possibly consider more CPU resources if the workload justifies it.

4. **Reassess Server Settings**  
   - If `CXPACKET` is consistently high, you may need to fine-tune parallelism. For instance, set `MAXDOP` to a lower value (like 4 or 8) or increase `cost threshold for parallelism` so that fewer smaller queries go parallel.

---

## Putting It All Together

1. **Focus on the Worst Offenders**  
   - From the high-impact queries list, pick the top 1–2 queries with the greatest resource usage.  
   - Check their execution plans, indexes, and parameters.  
   - Optimize them first—often, a single problematic query can significantly improve overall performance once tuned.

2. **Review Wait Stats in Context**  
   - High wait times confirm that your performance issues likely stem from CPU, I/O, or concurrency.  
   - Tackle the underlying hardware or configuration problem if you see consistent patterns (e.g., always I/O waits, always CPU waits).

3. **Iterate**  
   - After making changes (index creation, query rewrite, adjusting `MAXDOP`, etc.), re-run the queries and see if the high-impact queries move down in the list and if wait types shift.

4. **Establish a Baseline & Ongoing Monitoring**  
   - Regularly capture these stats (e.g., with a monitoring tool or scheduled job) to understand normal performance.  
   - Compare new results to past baselines whenever you suspect performance regressions.

---

### Additional Tips

- **Execution Plan Analysis**: Tools like SQL Server Management Studio (SSMS) “Include Actual Execution Plan” or third-party products (e.g., SQL Sentry Plan Explorer) can make it easier to interpret complex plans.  
- **Index Maintenance**: Ensure your indexes are well-maintained (rebuild or reorganize if fragmentation is high) and that stats are up to date.  
- **Parameter Sniffing**: If one parameter set runs well but others do not, consider solutions like “OPTIMIZE FOR UNKNOWN,” local variable usage, or forced parameterization.  
- **Incremental Improvements**: Tuning one query can reduce resource pressure for the entire system, so tackle queries in order of their impact rather than trying to fix everything at once.

---

## Conclusion

The results returned by the query are **diagnostic clues**. High CPU or I/O usage in the top queries indicates where to focus query/index tuning efforts. Top wait stats reveal **why** queries might be waiting—due to I/O bottlenecks, CPU pressure, or parallelism overhead. By **combining** these insights, you can systematically **optimize** your SQL Server environment:

1. **Request Application Developers to Optimize or rewrite** the top resource-consuming queries.  
2. **Tune indexes** to reduce I/O.  
3. **Address wait types** that show consistent bottlenecks (I/O, CPU, or concurrency).  
4. **Re-check** these stats to verify improvements.

Following this cycle will help ensure your SQL Server instance runs more efficiently and handles your workload with fewer slowdowns.
