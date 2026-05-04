$Db ='tcqss14_poolmgr'
$Db1 ='xplm_xsphere'

Copy-DbaDatabase -Source azwewpplmsqln-1 -Destination azwewtplmsql-1 -Database $Db -BackupRestore -SharedPath \\azwewtplmsql-1\TestSHare 
Copy-DbaDatabase -Source azwewpplmsqln-1 -Destination azwewtplmsql-1 -Database $Db1 -BackupRestore -SharedPath \\azwewtplmsql-1\TestSHare