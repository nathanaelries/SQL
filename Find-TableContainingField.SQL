SELECT Table_Name, 
    Column_Name
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = '<dbname>'
   AND COLUMN_NAME LIKE '%<searchstring>%';
