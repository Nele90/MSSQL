SELECT
name, is_disabled,
LOGINPROPERTY(name, N'isLocked') as is_locked,  
LOGINPROPERTY(name, N'PasswordLastSetTime') as PasswordLastSetTime,
LOGINPROPERTY(name, N'IsExpired') AS IsExpired
FROM sys.sql_logins
WHERE LOGINPROPERTY(name, N'isLocked') = 1
ORDER BY name; 
