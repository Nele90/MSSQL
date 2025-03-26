Import-Module 'C:\Program Files\WindowsPowerShell\Modules\dbatools.library'
Import-Module 'C:\Program Files\WindowsPowerShell\Modules\dbatools'
Set-DbatoolsConfig -Name Import.EncryptionMessageCheck -Value $false -PassThru | Register-DbatoolsConfig
Set-DbatoolsConfig -FullName 'sql.connection.trustcert' -Value $true -Register

Test-DbaBuild -SqlInstance provide list of servers -Update -MaxBehind 0CU  | Select-Object Build ,BuildLevel   ,BuildTarget ,Compliant ,CULevel  ,CUTarget  ,KBLevel   ,MatchType ,NameLevel,SPLevel  ,SPTarget ,SqlInstance,SupportedUntil  ,Warning |Write-DbaDbTableData -SqlInstance instancename -Database DBA_DB -Table dbo.SQL_Updates
