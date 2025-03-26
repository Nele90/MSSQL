Export-SqlUser -SqlInstance InsanceName -FilePath C:\temp\InsanceName-Users.sql
Notepad C:\temp\InsanceName-Users.sql 

## Export users from a database
Export-SqlUser -SqlInstance InsanceName -FilePath C:\temp\InsanceName-Fadetoblack.sql -Databases Fadetoblack
notepad C:\temp\InsanceName-Fadetoblack.sql   

## Export a single user from a database
Export-SqlUser -SqlInstance InsanceName -FilePath C:\temp\InsanceName-Lars-Fadetoblack.sql -User UlrichLars -Databases Fadetoblack
notepad C:\temp\InsanceName-Lars-Fadetoblack.sql         
