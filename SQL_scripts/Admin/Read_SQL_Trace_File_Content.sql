SELECT *
FROM fn_trace_gettable('C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log\log_49.trc', default)
where HostName = 'hosname'
