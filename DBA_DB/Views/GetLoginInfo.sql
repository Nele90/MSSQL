USE [DBA_DB]
GO

CREATE VIEW [dbo].[GetLoginInfo] AS
SELECT name
,TypeOfLogin            = type_desc
,'BadPasswordCount'     = LOGINPROPERTY(name, 'BadPasswordCount')
,'BadPasswordTime'      = LOGINPROPERTY(name, 'BadPasswordTime')
,'DaysUntilExpiration'  = LOGINPROPERTY(name, 'DaysUntilExpiration')
,'DefaultDatabase'      = LOGINPROPERTY(name, 'DefaultDatabase')
,'DefaultLanguage'      = LOGINPROPERTY(name, 'DefaultLanguage')
,'HistoryLength'        = LOGINPROPERTY(name, 'HistoryLength')
,'IsExpired'            = LOGINPROPERTY(name, 'IsExpired')
,'IsLocked'             = LOGINPROPERTY(name, 'IsLocked')
,'IsMustChange'         = LOGINPROPERTY(name, 'IsMustChange')
,'LockoutTime'          = LOGINPROPERTY(name, 'LockoutTime')
,'PasswordLastSetTime'  = LOGINPROPERTY(name, 'PasswordLastSetTime')
,'PasswordHashAlgorithm'= LOGINPROPERTY(name, 'PasswordHashAlgorithm')
,is_expiration_checked
,password_hash
,sid
,is_policy_checked
,create_date
FROM    sys.sql_logins
GO


